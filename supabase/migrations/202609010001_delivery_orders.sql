-- Delivery configuration and order workflow.
-- All delivery fees, branch selection, and distance validation happen in SQL,
-- never in the customer application.

create table public.branch_delivery_settings (
  branch_id uuid primary key references public.branches(id) on delete cascade,
  is_enabled boolean not null default false,
  maximum_distance_meters integer not null default 0
    check (maximum_distance_meters between 0 and 100000),
  minimum_order_kopeks integer not null default 15000
    check (minimum_order_kopeks = 15000),
  updated_at timestamptz not null default now()
);

create table public.branch_delivery_fee_tiers (
  id uuid primary key default extensions.gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  from_distance_meters integer not null check (from_distance_meters >= 0),
  to_distance_meters integer not null check (to_distance_meters > from_distance_meters),
  fee_kopeks integer not null check (fee_kopeks >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, from_distance_meters, to_distance_meters)
);

create table public.branch_drivers (
  id uuid primary key default extensions.gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 120),
  phone text check (char_length(btrim(phone)) between 5 and 30),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, full_name)
);

-- Existing branches receive a disabled settings row. A manager must explicitly
-- set a usable radius and fee tiers before customers can place delivery orders.
insert into public.branch_delivery_settings (branch_id)
select id from public.branches
on conflict (branch_id) do nothing;

create function public.create_delivery_settings_for_branch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.branch_delivery_settings (branch_id)
  values (new.id)
  on conflict (branch_id) do nothing;
  return new;
end;
$$;

create trigger branches_create_delivery_settings
after insert on public.branches
for each row execute function public.create_delivery_settings_for_branch();

alter table public.orders
  add column if not exists delivery_distance_meters integer
    check (delivery_distance_meters >= 0),
  add column if not exists delivery_scheduled_at timestamptz,
  add column if not exists delivery_driver_id uuid
    references public.branch_drivers(id) on delete set null;

-- Pickup keeps its original rule. A delivery needs both a textual address and
-- a point selected on the map; a requested delivery time is stored separately.
do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select conname
    from pg_constraint
    where conrelid = 'public.orders'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%fulfillment = ''delivery''%'
  loop
    execute format('alter table public.orders drop constraint %I', constraint_name);
  end loop;
end;
$$;

alter table public.orders
  add constraint orders_fulfillment_location_check
  check (
    (fulfillment = 'delivery'
      and delivery_address is not null
      and delivery_location is not null
      and delivery_distance_meters is not null)
    or
    (fulfillment = 'pickup'
      and delivery_address is null
      and delivery_location is null
      and delivery_distance_meters is null)
  );

create index branch_delivery_fee_tiers_branch_distance_idx
  on public.branch_delivery_fee_tiers (branch_id, from_distance_meters, to_distance_meters);
create index branch_drivers_branch_active_idx
  on public.branch_drivers (branch_id, is_active);
create index orders_delivery_driver_idx
  on public.orders (delivery_driver_id)
  where delivery_driver_id is not null;

create function public.ensure_delivery_fee_tier_does_not_overlap()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.branch_delivery_fee_tiers as tier
    where tier.branch_id = new.branch_id
      and tier.id is distinct from new.id
      and int4range(tier.from_distance_meters, tier.to_distance_meters, '[)')
          && int4range(new.from_distance_meters, new.to_distance_meters, '[)')
  ) then
    raise exception 'Delivery fee tiers cannot overlap';
  end if;
  return new;
end;
$$;

create trigger branch_delivery_fee_tiers_validate_ranges
before insert or update of branch_id, from_distance_meters, to_distance_meters
on public.branch_delivery_fee_tiers
for each row execute function public.ensure_delivery_fee_tier_does_not_overlap();

create trigger branch_delivery_settings_set_updated_at
before update on public.branch_delivery_settings
for each row execute function public.set_updated_at();
create trigger branch_delivery_fee_tiers_set_updated_at
before update on public.branch_delivery_fee_tiers
for each row execute function public.set_updated_at();
create trigger branch_drivers_set_updated_at
before update on public.branch_drivers
for each row execute function public.set_updated_at();

alter table public.branch_delivery_settings enable row level security;
alter table public.branch_delivery_fee_tiers enable row level security;
alter table public.branch_drivers enable row level security;

revoke all on public.branch_delivery_settings, public.branch_delivery_fee_tiers,
  public.branch_drivers from anon, authenticated;
grant select, insert, update on public.branch_delivery_settings to authenticated;
grant select, insert, update, delete on public.branch_delivery_fee_tiers to authenticated;
grant select, insert, update, delete on public.branch_drivers to authenticated;

create policy "delivery settings: managers manage their branch"
on public.branch_delivery_settings for all to authenticated
using (
  (select public.is_owner())
  or (select public.is_manager_for_branch(branch_id))
)
with check (
  (select public.is_owner())
  or (select public.is_manager_for_branch(branch_id))
);

create policy "delivery fee tiers: managers manage their branch"
on public.branch_delivery_fee_tiers for all to authenticated
using (
  (select public.is_owner())
  or (select public.is_manager_for_branch(branch_id))
)
with check (
  (select public.is_owner())
  or (select public.is_manager_for_branch(branch_id))
);

create policy "drivers: owner manages all"
on public.branch_drivers for all to authenticated
using ((select public.is_owner()))
with check ((select public.is_owner()));

-- Managers need a narrow, read-only list of active drivers in their own
-- branch to assign a delivery. The driver table itself remains owner-only.
create function public.get_branch_drivers_for_assignment(p_branch_id uuid)
returns table (id uuid, full_name text, phone text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.can_manage_branch(p_branch_id) then
    raise exception 'You cannot view drivers for this branch';
  end if;
  return query
  select driver.id, driver.full_name, driver.phone
  from public.branch_drivers as driver
  where driver.branch_id = p_branch_id
    and driver.is_active
  order by driver.full_name;
end;
$$;

-- Returns the secure price quote for a customer pin. It deliberately considers
-- only operational branches that can serve every requested menu line.
create function public.get_delivery_quote(
  p_latitude numeric,
  p_longitude numeric,
  p_items jsonb
)
returns table (
  branch_id uuid,
  branch_name text,
  branch_address text,
  distance_meters integer,
  delivery_fee_kopeks integer,
  minimum_order_kopeks integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'A valid address pin is required';
  end if;
  if coalesce(jsonb_typeof(p_items), '') <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'An order must include at least one item';
  end if;

  return query
  with customer_point as (
    select extensions.ST_SetSRID(extensions.ST_MakePoint(p_longitude, p_latitude), 4326) as point
  ), candidates as (
    select
      branch.id,
      branch.name,
      branch.address,
      settings.minimum_order_kopeks,
      round(extensions.ST_Distance(branch.location::extensions.geography, customer_point.point::extensions.geography))::integer as meters
    from public.branches as branch
    join public.branch_delivery_settings as settings on settings.branch_id = branch.id
    cross join customer_point
    where branch.is_active
      and settings.is_enabled
      and round(extensions.ST_Distance(branch.location::extensions.geography, customer_point.point::extensions.geography)) <= settings.maximum_distance_meters
      and not exists (
        select 1
        from jsonb_to_recordset(p_items) as requested(menu_item_id uuid, menu_item_variant_id uuid)
        left join public.branch_menu_items as branch_item
          on branch_item.branch_id = branch.id
         and branch_item.menu_item_id = requested.menu_item_id
         and branch_item.is_available
        left join public.menu_items as menu_item
          on menu_item.id = requested.menu_item_id and menu_item.is_active
        left join public.menu_item_variants as variant
          on variant.id = requested.menu_item_variant_id
         and variant.menu_item_id = requested.menu_item_id
         and variant.is_active
        left join public.branch_menu_item_variants as branch_variant
          on branch_variant.branch_id = branch.id
         and branch_variant.menu_item_id = requested.menu_item_id
         and branch_variant.menu_item_variant_id = requested.menu_item_variant_id
         and branch_variant.is_available
        where branch_item.branch_id is null
           or menu_item.id is null
           or variant.id is null
           or branch_variant.branch_id is null
      )
      and not exists (
        select 1
        from jsonb_to_recordset(p_items) as requested(
          menu_item_id uuid,
          modifier_option_ids jsonb
        )
        cross join lateral jsonb_array_elements_text(
          coalesce(requested.modifier_option_ids, '[]'::jsonb)
        ) as picked(option_id)
        where not exists (
          select 1
          from public.menu_items as item
          join public.menu_item_modifier_options as option
            on option.id = picked.option_id::uuid and option.is_active
          join public.menu_item_modifier_groups as modifier_group
            on modifier_group.id = option.menu_item_modifier_group_id
           and modifier_group.is_active
          join public.branch_menu_item_modifier_options as branch_option
            on branch_option.menu_item_modifier_option_id = option.id
           and branch_option.branch_id = branch.id
           and branch_option.is_available
          where item.id = requested.menu_item_id
            and (modifier_group.menu_item_id = item.id
              or modifier_group.menu_category_id = item.category_id)
        )
      )
  )
  select
    candidate.id,
    candidate.name,
    candidate.address,
    candidate.meters,
    tier.fee_kopeks,
    candidate.minimum_order_kopeks
  from candidates as candidate
  join public.branch_delivery_fee_tiers as tier
    on tier.branch_id = candidate.id
   and candidate.meters >= tier.from_distance_meters
   and candidate.meters < tier.to_distance_meters
  order by candidate.meters, candidate.name
  limit 1;
end;
$$;

create function public.place_delivery_cash_order(
  p_items jsonb,
  p_contact_name text,
  p_contact_phone text,
  p_delivery_address text,
  p_delivery_latitude numeric,
  p_delivery_longitude numeric,
  p_delivery_scheduled_at timestamptz default null,
  p_customer_notes text default null,
  p_idempotency_key uuid default extensions.gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id uuid;
  v_quote record;
  v_subtotal integer;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if nullif(btrim(coalesce(p_delivery_address, '')), '') is null then
    raise exception 'A delivery address is required';
  end if;
  if p_delivery_scheduled_at is not null then
    if p_delivery_scheduled_at <= now() then
      raise exception 'A delivery time must be in the future';
    end if;
    if (p_delivery_scheduled_at at time zone 'Europe/Moscow')::date
        <> (now() at time zone 'Europe/Moscow')::date then
      raise exception 'Delivery can only be scheduled for today';
    end if;
  end if;

  select id into v_order_id
  from public.orders
  where customer_id = auth.uid()
    and idempotency_key = p_idempotency_key;
  if found then
    return v_order_id;
  end if;

  select * into v_quote
  from public.get_delivery_quote(p_delivery_latitude, p_delivery_longitude, p_items);
  if not found then
    raise exception 'No available branch can deliver this order to the selected address';
  end if;

  -- The pickup routine is reused for server-side menu, price, modifier and
  -- idempotency validation. This transaction then turns its new order into a
  -- delivery order using the quote calculated above.
  v_order_id := public.place_cash_order(
    'pickup'::public.fulfillment_type,
    v_quote.branch_id,
    p_items,
    p_contact_name,
    p_contact_phone,
    null,
    null,
    null,
    null,
    p_customer_notes,
    p_idempotency_key
  );

  select subtotal_kopeks into v_subtotal
  from public.orders
  where id = v_order_id;

  if v_subtotal < v_quote.minimum_order_kopeks then
    raise exception 'The minimum delivery order is % ₽', v_quote.minimum_order_kopeks / 100;
  end if;

  update public.orders
  set fulfillment = 'delivery',
      delivery_address = btrim(p_delivery_address),
      delivery_location = extensions.ST_SetSRID(
        extensions.ST_MakePoint(p_delivery_longitude, p_delivery_latitude), 4326
      ),
      delivery_distance_meters = v_quote.distance_meters,
      delivery_fee_kopeks = v_quote.delivery_fee_kopeks,
      total_kopeks = v_subtotal + v_quote.delivery_fee_kopeks,
      delivery_scheduled_at = p_delivery_scheduled_at
  where id = v_order_id;

  return v_order_id;
end;
$$;

create function public.assign_order_driver(
  p_order_id uuid,
  p_driver_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_driver_name text;
begin
  select branch_id into v_branch_id from public.orders where id = p_order_id and fulfillment = 'delivery';
  if v_branch_id is null or not public.can_manage_branch(v_branch_id) then
    raise exception 'You cannot manage this delivery order';
  end if;

  select full_name into v_driver_name
  from public.branch_drivers
  where id = p_driver_id and branch_id = v_branch_id and is_active;
  if v_driver_name is null then
    raise exception 'Select an active driver from this branch';
  end if;

  update public.orders
  set delivery_driver_id = p_driver_id,
      driver_name = v_driver_name
  where id = p_order_id;
end;
$$;

-- Preserve a selected driver when moving a delivery order to "on the way".
create or replace function public.manager_update_order_status(
  p_order_id uuid,
  p_next_status public.order_status,
  p_reason text default null,
  p_driver_name text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
begin
  select branch_id into v_branch_id from public.orders where id = p_order_id;
  if v_branch_id is null or not public.can_manage_branch(v_branch_id) then
    raise exception 'You cannot manage this order';
  end if;

  if p_next_status = 'out_for_delivery' and not exists (
    select 1
    from public.orders
    where id = p_order_id
      and fulfillment = 'delivery'
      and delivery_driver_id is not null
  ) then
    raise exception 'A delivery driver must be assigned before dispatch';
  end if;

  update public.orders
  set status = p_next_status,
      cancellation_reason = case
        when p_next_status in ('rejected', 'cancelled') then nullif(btrim(coalesce(p_reason, '')), '')
        else cancellation_reason
      end,
      driver_name = case
        when p_next_status = 'out_for_delivery'
          then coalesce(nullif(btrim(coalesce(p_driver_name, '')), ''), driver_name)
        else driver_name
      end
  where id = p_order_id;
end;
$$;

revoke execute on function public.get_delivery_quote(numeric, numeric, jsonb) from public, anon;
revoke execute on function public.place_delivery_cash_order(jsonb, text, text, text, numeric, numeric, timestamptz, text, uuid) from public, anon;
revoke execute on function public.assign_order_driver(uuid, uuid) from public, anon;
grant execute on function public.get_delivery_quote(numeric, numeric, jsonb) to authenticated;
grant execute on function public.place_delivery_cash_order(jsonb, text, text, text, numeric, numeric, timestamptz, text, uuid) to authenticated;
grant execute on function public.assign_order_driver(uuid, uuid) to authenticated;
grant execute on function public.get_branch_drivers_for_assignment(uuid) to authenticated;
grant execute on function public.manager_update_order_status(uuid, public.order_status, text, text) to authenticated;

alter function public.get_delivery_quote(numeric, numeric, jsonb) set search_path = '';
alter function public.place_delivery_cash_order(jsonb, text, text, text, numeric, numeric, timestamptz, text, uuid) set search_path = '';
alter function public.assign_order_driver(uuid, uuid) set search_path = '';
alter function public.get_branch_drivers_for_assignment(uuid) set search_path = '';
alter function public.manager_update_order_status(uuid, public.order_status, text, text) set search_path = '';
