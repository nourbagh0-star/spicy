-- Spicy initial restaurant platform schema.
-- Apply this migration through the Supabase CLI after linking the project.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists postgis with schema extensions;

create type public.app_role as enum ('owner', 'manager', 'customer');
create type public.fulfillment_type as enum ('delivery', 'pickup');
create type public.order_source as enum ('customer', 'manager');
create type public.order_status as enum (
  'pending',
  'accepted',
  'rejected',
  'preparing',
  'ready_for_pickup',
  'out_for_delivery',
  'completed',
  'cancelled'
);
create type public.payment_status as enum ('unpaid', 'paid', 'voided');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.app_role not null default 'customer',
  assigned_branch_id uuid,
  full_name text,
  contact_phone text,
  preferred_locale text not null default 'ru'
    check (preferred_locale in ('ru', 'en', 'ar')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  public_phone text,
  map_reference_url text,
  location extensions.geometry(Point, 4326) not null,
  opening_hours jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add constraint profiles_assigned_branch_id_fkey
  foreign key (assigned_branch_id) references public.branches (id)
  on delete set null;

create table public.restaurant_settings (
  singleton boolean primary key default true check (singleton),
  currency_code text not null default 'RUB' check (currency_code = 'RUB'),
  delivery_fee_kopeks integer not null default 15000
    check (delivery_fee_kopeks >= 0),
  updated_at timestamptz not null default now()
);

insert into public.restaurant_settings (singleton, currency_code, delivery_fee_kopeks)
values (true, 'RUB', 15000);

create table public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  name text not null,
  boundary extensions.geometry(MultiPolygon, 4326) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  external_id text unique,
  slug text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.menu_category_translations (
  category_id uuid not null references public.menu_categories (id) on delete cascade,
  language_code text not null check (language_code in ('ru', 'en', 'ar')),
  name text not null,
  primary key (category_id, language_code)
);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  external_id text unique,
  category_id uuid not null references public.menu_categories (id) on delete restrict,
  image_url text,
  storage_path text,
  heat_level smallint not null default 0 check (heat_level between 0 and 5),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (image_url is not null or storage_path is not null)
);

create table public.menu_item_translations (
  menu_item_id uuid not null references public.menu_items (id) on delete cascade,
  language_code text not null check (language_code in ('ru', 'en', 'ar')),
  name text not null,
  description text not null default '',
  ingredients text[] not null default '{}',
  primary key (menu_item_id, language_code)
);

create table public.branch_menu_items (
  branch_id uuid not null references public.branches (id) on delete cascade,
  menu_item_id uuid not null references public.menu_items (id) on delete restrict,
  price_kopeks integer not null check (price_kopeks >= 0),
  preparation_time_minutes integer not null default 20
    check (preparation_time_minutes between 1 and 720),
  is_available boolean not null default true,
  is_branch_only boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (branch_id, menu_item_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  customer_id uuid not null references public.profiles (id) on delete restrict,
  branch_id uuid not null references public.branches (id) on delete restrict,
  source public.order_source not null default 'customer',
  fulfillment public.fulfillment_type not null,
  status public.order_status not null default 'pending',
  payment_status public.payment_status not null default 'unpaid',
  currency_code text not null default 'RUB' check (currency_code = 'RUB'),
  subtotal_kopeks integer not null check (subtotal_kopeks >= 0),
  delivery_fee_kopeks integer not null default 0 check (delivery_fee_kopeks >= 0),
  total_kopeks integer not null check (total_kopeks >= 0),
  contact_name text not null,
  contact_phone text,
  delivery_address text,
  delivery_location extensions.geometry(Point, 4326),
  pickup_at timestamptz,
  customer_notes text,
  driver_name text,
  cancellation_reason text,
  idempotency_key uuid not null default gen_random_uuid(),
  cash_received_at timestamptz,
  accepted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, idempotency_key),
  check (total_kopeks = subtotal_kopeks + delivery_fee_kopeks),
  check (
    (fulfillment = 'delivery' and delivery_address is not null and delivery_location is not null and pickup_at is null)
    or
    (fulfillment = 'pickup' and delivery_address is null and delivery_location is null)
  )
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  menu_item_id uuid references public.menu_items (id) on delete restrict,
  item_name text not null,
  item_description text not null default '',
  image_url text,
  quantity integer not null check (quantity between 1 and 100),
  unit_price_kopeks integer not null check (unit_price_kopeks >= 0),
  line_total_kopeks integer not null check (line_total_kopeks >= 0),
  special_instructions text,
  check (line_total_kopeks = quantity * unit_price_kopeks)
);

create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  previous_status public.order_status,
  next_status public.order_status not null,
  changed_by uuid references public.profiles (id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

create index delivery_zones_branch_id_idx on public.delivery_zones (branch_id);
create index menu_items_category_id_idx on public.menu_items (category_id);
create index branch_menu_items_available_idx on public.branch_menu_items (branch_id, is_available);
create index orders_customer_created_idx on public.orders (customer_id, created_at desc);
create index orders_branch_status_created_idx on public.orders (branch_id, status, created_at desc);
create index order_items_order_id_idx on public.order_items (order_id);
create index order_status_history_order_id_idx on public.order_status_history (order_id, created_at);
create index branches_location_idx on public.branches using gist (location);
create index delivery_zones_boundary_idx on public.delivery_zones using gist (boundary);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''));
  return new;
end;
$$;

create function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid() and role = 'owner'
  );
$$;

create function public.is_manager_for_branch(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'manager'
      and assigned_branch_id = p_branch_id
  );
$$;

create function public.can_manage_branch(p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_owner() or public.is_manager_for_branch(p_branch_id);
$$;

create function public.delivery_fee_kopeks()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select delivery_fee_kopeks from public.restaurant_settings where singleton;
$$;

create function public.is_valid_order_transition(
  p_previous public.order_status,
  p_next public.order_status
)
returns boolean
language sql
immutable
as $$
  select case p_previous
    when 'pending' then p_next in ('accepted', 'rejected', 'cancelled')
    when 'accepted' then p_next in ('preparing', 'cancelled')
    when 'preparing' then p_next in ('ready_for_pickup', 'out_for_delivery', 'cancelled')
    when 'ready_for_pickup' then p_next in ('completed', 'cancelled')
    when 'out_for_delivery' then p_next in ('completed', 'cancelled')
    else false
  end;
$$;

create function public.validate_order_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status <> old.status then
    if not public.is_valid_order_transition(old.status, new.status) then
      raise exception 'Invalid order status transition from % to %', old.status, new.status;
    end if;

    if new.status in ('rejected', 'cancelled')
      and nullif(trim(coalesce(new.cancellation_reason, '')), '') is null then
      raise exception 'A reason is required when rejecting or cancelling an order';
    end if;

    if new.status = 'out_for_delivery'
      and nullif(trim(coalesce(new.driver_name, '')), '') is null then
      raise exception 'A driver name is required before dispatching an order';
    end if;

    if new.status = 'accepted' then
      new.accepted_at = coalesce(new.accepted_at, now());
    end if;

    if new.status = 'completed' then
      new.completed_at = coalesce(new.completed_at, now());
      new.cash_received_at = coalesce(new.cash_received_at, now());
      new.payment_status = 'paid';
    elsif new.status in ('rejected', 'cancelled') then
      new.payment_status = 'voided';
    end if;
  end if;

  return new;
end;
$$;

create function public.record_order_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status <> old.status then
    insert into public.order_status_history (
      order_id,
      previous_status,
      next_status,
      changed_by,
      reason
    ) values (
      new.id,
      old.status,
      new.status,
      auth.uid(),
      case
        when new.status in ('rejected', 'cancelled') then new.cancellation_reason
        else null
      end
    );
  end if;
  return new;
end;
$$;

create function public.place_cash_order(
  p_fulfillment public.fulfillment_type,
  p_branch_id uuid,
  p_items jsonb,
  p_contact_name text,
  p_contact_phone text default null,
  p_delivery_address text default null,
  p_delivery_latitude numeric default null,
  p_delivery_longitude numeric default null,
  p_pickup_at timestamptz default null,
  p_customer_notes text default null,
  p_idempotency_key uuid default gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_order_id uuid;
  v_subtotal integer;
  v_delivery_fee integer := 0;
  v_delivery_point extensions.geometry(Point, 4326);
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if nullif(trim(coalesce(p_contact_name, '')), '') is null then
    raise exception 'A customer name is required';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'An order must include at least one item';
  end if;

  select id into v_order_id
  from public.orders
  where customer_id = auth.uid() and idempotency_key = p_idempotency_key;

  if found then
    return v_order_id;
  end if;

  if not exists (
    select 1 from public.branches where id = p_branch_id and is_active
  ) then
    raise exception 'The selected branch is unavailable';
  end if;

  if p_fulfillment = 'delivery' then
    if nullif(trim(coalesce(p_delivery_address, '')), '') is null
      or p_delivery_latitude is null
      or p_delivery_longitude is null then
      raise exception 'A delivery address and map location are required';
    end if;

    v_delivery_point := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_delivery_longitude, p_delivery_latitude),
      4326
    );

    if not exists (
      select 1
      from public.delivery_zones
      where branch_id = p_branch_id
        and is_active
        and extensions.ST_Covers(boundary, v_delivery_point)
    ) then
      raise exception 'The selected branch does not deliver to this address';
    end if;

    v_delivery_fee := public.delivery_fee_kopeks();
  elsif p_pickup_at is not null and p_pickup_at < now() then
    raise exception 'A pickup time cannot be in the past';
  end if;

  select coalesce(sum(request.quantity * branch_item.price_kopeks), 0)
  into v_subtotal
  from jsonb_to_recordset(p_items) as request(menu_item_id uuid, quantity integer)
  join public.branch_menu_items branch_item
    on branch_item.menu_item_id = request.menu_item_id
   and branch_item.branch_id = p_branch_id
   and branch_item.is_available
  join public.menu_items item
    on item.id = request.menu_item_id
   and item.is_active
  where request.quantity between 1 and 100;

  if v_subtotal = 0 then
    raise exception 'No available menu items were supplied';
  end if;

  if (
    select count(*)
    from jsonb_to_recordset(p_items) as request(menu_item_id uuid, quantity integer)
    where quantity between 1 and 100
  ) <> jsonb_array_length(p_items) then
    raise exception 'Every item quantity must be between 1 and 100';
  end if;

  if (
    select count(*)
    from jsonb_to_recordset(p_items) as request(menu_item_id uuid, quantity integer)
    join public.branch_menu_items branch_item
      on branch_item.menu_item_id = request.menu_item_id
     and branch_item.branch_id = p_branch_id
     and branch_item.is_available
    join public.menu_items item
      on item.id = request.menu_item_id
     and item.is_active
  ) <> jsonb_array_length(p_items) then
    raise exception 'One or more menu items are unavailable at this branch';
  end if;

  insert into public.orders (
    customer_id,
    branch_id,
    fulfillment,
    subtotal_kopeks,
    delivery_fee_kopeks,
    total_kopeks,
    contact_name,
    contact_phone,
    delivery_address,
    delivery_location,
    pickup_at,
    customer_notes,
    idempotency_key
  ) values (
    auth.uid(),
    p_branch_id,
    p_fulfillment,
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee,
    trim(p_contact_name),
    nullif(trim(coalesce(p_contact_phone, '')), ''),
    case when p_fulfillment = 'delivery' then trim(p_delivery_address) else null end,
    case when p_fulfillment = 'delivery' then v_delivery_point else null end,
    case when p_fulfillment = 'pickup' then p_pickup_at else null end,
    nullif(trim(coalesce(p_customer_notes, '')), ''),
    p_idempotency_key
  ) returning id into v_order_id;

  insert into public.order_items (
    order_id,
    menu_item_id,
    item_name,
    item_description,
    image_url,
    quantity,
    unit_price_kopeks,
    line_total_kopeks,
    special_instructions
  )
  select
    v_order_id,
    item.id,
    translation.name,
    translation.description,
    coalesce(item.storage_path, item.image_url),
    request.quantity,
    branch_item.price_kopeks,
    request.quantity * branch_item.price_kopeks,
    nullif(trim(coalesce(request.special_instructions, '')), '')
  from jsonb_to_recordset(p_items) as request(
    menu_item_id uuid,
    quantity integer,
    special_instructions text
  )
  join public.branch_menu_items branch_item
    on branch_item.menu_item_id = request.menu_item_id
   and branch_item.branch_id = p_branch_id
  join public.menu_items item on item.id = request.menu_item_id
  join public.menu_item_translations translation
    on translation.menu_item_id = item.id
   and translation.language_code = 'ru';

  insert into public.order_status_history (
    order_id,
    next_status,
    changed_by,
    reason
  ) values (v_order_id, 'pending', auth.uid(), 'Customer cash order created');

  return v_order_id;
end;
$$;

create function public.cancel_pending_order(
  p_order_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set status = 'cancelled', cancellation_reason = nullif(trim(p_reason), '')
  where id = p_order_id
    and customer_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'Only a pending order belonging to the current customer can be cancelled';
  end if;
end;
$$;

create function public.manager_update_order_status(
  p_order_id uuid,
  p_next_status public.order_status,
  p_reason text default null,
  p_driver_name text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_branch_id uuid;
begin
  select branch_id into v_branch_id from public.orders where id = p_order_id;

  if v_branch_id is null or not public.can_manage_branch(v_branch_id) then
    raise exception 'You cannot manage this order';
  end if;

  update public.orders
  set status = p_next_status,
      cancellation_reason = case
        when p_next_status in ('rejected', 'cancelled') then nullif(trim(coalesce(p_reason, '')), '')
        else cancellation_reason
      end,
      driver_name = case
        when p_next_status = 'out_for_delivery' then nullif(trim(coalesce(p_driver_name, '')), '')
        else driver_name
      end
  where id = p_order_id;
end;
$$;

create function public.eligible_branches_for_location(
  p_latitude numeric,
  p_longitude numeric
)
returns table (branch_id uuid, distance_meters integer)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with customer_point as (
    select extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_longitude, p_latitude),
      4326
    ) as point
  )
  select
    branch.id,
    round(extensions.ST_Distance(branch.location::extensions.geography, customer_point.point::extensions.geography))::integer as distance_meters
  from public.branches branch
  cross join customer_point
  where branch.is_active
    and exists (
      select 1
      from public.delivery_zones zone
      where zone.branch_id = branch.id
        and zone.is_active
        and extensions.ST_Covers(zone.boundary, customer_point.point)
    )
  order by distance_meters, branch.name;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger branches_set_updated_at
before update on public.branches
for each row execute function public.set_updated_at();

create trigger delivery_zones_set_updated_at
before update on public.delivery_zones
for each row execute function public.set_updated_at();

create trigger menu_categories_set_updated_at
before update on public.menu_categories
for each row execute function public.set_updated_at();

create trigger menu_items_set_updated_at
before update on public.menu_items
for each row execute function public.set_updated_at();

create trigger branch_menu_items_set_updated_at
before update on public.branch_menu_items
for each row execute function public.set_updated_at();

create trigger restaurant_settings_set_updated_at
before update on public.restaurant_settings
for each row execute function public.set_updated_at();

create trigger orders_validate_status_change
before update on public.orders
for each row execute function public.validate_order_status_change();

create trigger orders_record_status_change
after update on public.orders
for each row execute function public.record_order_status_change();

create trigger auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.branches enable row level security;
alter table public.restaurant_settings enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_category_translations enable row level security;
alter table public.menu_items enable row level security;
alter table public.menu_item_translations enable row level security;
alter table public.branch_menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;

create policy "profiles: users read themselves or owners read all"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_owner());

create policy "profiles: users update their own personal details"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "branches: authenticated users read active branches"
on public.branches for select to authenticated
using (is_active or public.can_manage_branch(id));

create policy "branches: owners manage all"
on public.branches for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "settings: owners manage"
on public.restaurant_settings for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "zones: branch managers and owners manage their zones"
on public.delivery_zones for all to authenticated
using (public.can_manage_branch(branch_id))
with check (public.can_manage_branch(branch_id));

create policy "categories: authenticated users read"
on public.menu_categories for select to authenticated
using (is_active or public.is_owner());

create policy "categories: owners manage"
on public.menu_categories for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "category translations: authenticated users read"
on public.menu_category_translations for select to authenticated
using (true);

create policy "category translations: owners manage"
on public.menu_category_translations for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "menu items: authenticated users read"
on public.menu_items for select to authenticated
using (is_active or public.is_owner());

create policy "menu items: owners manage"
on public.menu_items for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "menu translations: authenticated users read"
on public.menu_item_translations for select to authenticated
using (true);

create policy "menu translations: owners manage"
on public.menu_item_translations for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "branch menu: authenticated users read"
on public.branch_menu_items for select to authenticated
using (true);

create policy "branch menu: owners manage"
on public.branch_menu_items for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "orders: customers read their own orders"
on public.orders for select to authenticated
using (customer_id = auth.uid() or public.can_manage_branch(branch_id));

create policy "order items: users read items for visible orders"
on public.order_items for select to authenticated
using (
  exists (
    select 1 from public.orders
    where orders.id = order_items.order_id
      and (orders.customer_id = auth.uid() or public.can_manage_branch(orders.branch_id))
  )
);

create policy "order history: users read visible order history"
on public.order_status_history for select to authenticated
using (
  exists (
    select 1 from public.orders
    where orders.id = order_status_history.order_id
      and (orders.customer_id = auth.uid() or public.can_manage_branch(orders.branch_id))
  )
);

revoke all on public.orders, public.order_items, public.order_status_history from authenticated;
grant select on public.orders, public.order_items, public.order_status_history to authenticated;

revoke update on public.profiles from authenticated;
grant update (full_name, contact_phone, preferred_locale, updated_at)
on public.profiles to authenticated;

revoke all on function public.place_cash_order(
  public.fulfillment_type,
  uuid,
  jsonb,
  text,
  text,
  text,
  numeric,
  numeric,
  timestamptz,
  text,
  uuid
) from public;
revoke all on function public.cancel_pending_order(uuid, text) from public;
revoke all on function public.manager_update_order_status(uuid, public.order_status, text, text) from public;
revoke all on function public.eligible_branches_for_location(numeric, numeric) from public;
revoke all on function public.delivery_fee_kopeks() from public;

grant execute on function public.place_cash_order(
  public.fulfillment_type,
  uuid,
  jsonb,
  text,
  text,
  text,
  numeric,
  numeric,
  timestamptz,
  text,
  uuid
) to authenticated;
grant execute on function public.cancel_pending_order(uuid, text) to authenticated;
grant execute on function public.manager_update_order_status(uuid, public.order_status, text, text) to authenticated;
grant execute on function public.eligible_branches_for_location(numeric, numeric) to authenticated;
grant execute on function public.delivery_fee_kopeks() to authenticated;
