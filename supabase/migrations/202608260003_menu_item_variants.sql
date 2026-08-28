-- Adds a normalized price-option model before the initial menu is imported.
-- Every sellable item will receive one or more variants. The checkout RPC
-- trusts only prices calculated by this database.

begin;

-- The initial menu has not been imported yet. Stop rather than discarding a
-- manually-created catalog if this migration is ever applied too late.
do $$
begin
  if exists (select 1 from public.branch_menu_items)
     or exists (select 1 from public.order_items) then
    raise exception
      'Menu variants must be installed before menu items or order lines exist';
  end if;
end;
$$;

alter table public.menu_items
  add column sort_order integer not null default 0;

-- Price is now held at the selectable option level. No catalog data exists
-- yet, so removing this unused column avoids two conflicting price sources.
alter table public.branch_menu_items
  drop column price_kopeks;

create table public.menu_item_variants (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items (id) on delete restrict,
  code text not null check (btrim(code) <> ''),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (menu_item_id, code),
  unique (id, menu_item_id)
);

create table public.menu_item_variant_translations (
  menu_item_variant_id uuid not null
    references public.menu_item_variants (id) on delete cascade,
  language_code text not null check (language_code in ('ru', 'en', 'ar')),
  name text not null check (btrim(name) <> ''),
  primary key (menu_item_variant_id, language_code)
);

create table public.branch_menu_item_variants (
  branch_id uuid not null,
  menu_item_id uuid not null,
  menu_item_variant_id uuid not null,
  price_kopeks integer not null check (price_kopeks >= 0),
  is_available boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (branch_id, menu_item_variant_id),
  foreign key (branch_id, menu_item_id)
    references public.branch_menu_items (branch_id, menu_item_id)
    on delete cascade,
  foreign key (menu_item_variant_id, menu_item_id)
    references public.menu_item_variants (id, menu_item_id)
    on delete restrict
);

alter table public.order_items
  add column menu_item_variant_id uuid not null,
  add column variant_name text not null check (btrim(variant_name) <> '');

alter table public.order_items
  add constraint order_items_variant_matches_item_fkey
  foreign key (menu_item_variant_id, menu_item_id)
  references public.menu_item_variants (id, menu_item_id)
  on delete restrict;

create index menu_item_variants_item_active_idx
  on public.menu_item_variants (menu_item_id, is_active, sort_order);
create index branch_menu_item_variants_branch_item_available_idx
  on public.branch_menu_item_variants (
    branch_id,
    menu_item_id,
    is_available
  );

create trigger menu_item_variants_set_updated_at
before update on public.menu_item_variants
for each row execute function public.set_updated_at();

create trigger branch_menu_item_variants_set_updated_at
before update on public.branch_menu_item_variants
for each row execute function public.set_updated_at();

alter table public.menu_item_variants enable row level security;
alter table public.menu_item_variant_translations enable row level security;
alter table public.branch_menu_item_variants enable row level security;

create policy "menu variants: authenticated users read active catalog"
on public.menu_item_variants for select to authenticated
using (
  public.is_owner()
  or exists (
    select 1
    from public.menu_items item
    where item.id = menu_item_variants.menu_item_id
      and item.is_active
  )
);

create policy "menu variants: owners manage"
on public.menu_item_variants for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "menu variant translations: authenticated users read active catalog"
on public.menu_item_variant_translations for select to authenticated
using (
  public.is_owner()
  or exists (
    select 1
    from public.menu_item_variants variant
    join public.menu_items item on item.id = variant.menu_item_id
    where variant.id = menu_item_variant_translations.menu_item_variant_id
      and variant.is_active
      and item.is_active
  )
);

create policy "menu variant translations: owners manage"
on public.menu_item_variant_translations for all to authenticated
using (public.is_owner())
with check (public.is_owner());

create policy "branch menu variants: users read visible prices"
on public.branch_menu_item_variants for select to authenticated
using (
  public.is_owner()
  or public.is_manager_for_branch(branch_id)
  or exists (
    select 1
    from public.branches branch
    join public.branch_menu_items branch_item
      on branch_item.branch_id = branch.id
     and branch_item.menu_item_id = branch_menu_item_variants.menu_item_id
    join public.menu_items item
      on item.id = branch_item.menu_item_id
    join public.menu_item_variants variant
      on variant.id = branch_menu_item_variants.menu_item_variant_id
    where branch.id = branch_menu_item_variants.branch_id
      and branch.is_active
      and branch_item.is_available
      and branch_menu_item_variants.is_available
      and item.is_active
      and variant.is_active
  )
);

create policy "branch menu variants: owners manage"
on public.branch_menu_item_variants for all to authenticated
using (public.is_owner())
with check (public.is_owner());

revoke all on public.menu_item_variants,
  public.menu_item_variant_translations,
  public.branch_menu_item_variants from anon;
grant select, insert, update, delete on public.menu_item_variants,
  public.menu_item_variant_translations,
  public.branch_menu_item_variants to authenticated;

-- Returns only the selected branch's currently purchasable menu. The client
-- gets stable IDs and localised display text, but never controls a price.
create function public.get_branch_menu(
  p_branch_id uuid,
  p_language_code text default 'ru'
)
returns table (
  category_id uuid,
  category_slug text,
  category_sort_order integer,
  category_name text,
  menu_item_id uuid,
  external_id text,
  item_sort_order integer,
  item_name text,
  item_description text,
  image_url text,
  storage_path text,
  heat_level smallint,
  variant_id uuid,
  variant_code text,
  variant_sort_order integer,
  variant_name text,
  price_kopeks integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if coalesce(p_language_code, 'ru') not in ('ru', 'en', 'ar') then
    raise exception 'Unsupported language code';
  end if;

  return query
  select
    category.id,
    category.slug,
    category.sort_order,
    coalesce(category_locale.name, category_ru.name),
    item.id,
    item.external_id,
    item.sort_order,
    coalesce(item_locale.name, item_ru.name),
    coalesce(item_locale.description, item_ru.description),
    item.image_url,
    item.storage_path,
    item.heat_level,
    variant.id,
    variant.code,
    variant.sort_order,
    coalesce(variant_locale.name, variant_ru.name),
    branch_variant.price_kopeks
  from public.branches branch
  join public.branch_menu_items branch_item
    on branch_item.branch_id = branch.id
   and branch_item.is_available
  join public.menu_items item
    on item.id = branch_item.menu_item_id
   and item.is_active
  join public.menu_categories category
    on category.id = item.category_id
   and category.is_active
  join public.menu_item_variants variant
    on variant.menu_item_id = item.id
   and variant.is_active
  join public.branch_menu_item_variants branch_variant
    on branch_variant.branch_id = branch.id
   and branch_variant.menu_item_id = item.id
   and branch_variant.menu_item_variant_id = variant.id
   and branch_variant.is_available
  join public.menu_category_translations category_ru
    on category_ru.category_id = category.id
   and category_ru.language_code = 'ru'
  left join public.menu_category_translations category_locale
    on category_locale.category_id = category.id
   and category_locale.language_code = coalesce(p_language_code, 'ru')
  join public.menu_item_translations item_ru
    on item_ru.menu_item_id = item.id
   and item_ru.language_code = 'ru'
  left join public.menu_item_translations item_locale
    on item_locale.menu_item_id = item.id
   and item_locale.language_code = coalesce(p_language_code, 'ru')
  join public.menu_item_variant_translations variant_ru
    on variant_ru.menu_item_variant_id = variant.id
   and variant_ru.language_code = 'ru'
  left join public.menu_item_variant_translations variant_locale
    on variant_locale.menu_item_variant_id = variant.id
   and variant_locale.language_code = coalesce(p_language_code, 'ru')
  where branch.id = p_branch_id
    and branch.is_active
  order by category.sort_order, item.sort_order, variant.sort_order;
end;
$$;

-- p_items must contain objects with menu_item_id, menu_item_variant_id,
-- quantity, and optional special_instructions. Prices and names are always
-- recalculated and snapshotted by the database.
create or replace function public.place_cash_order(
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
  v_resolved_items jsonb;
  v_resolved_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if nullif(trim(coalesce(p_contact_name, '')), '') is null then
    raise exception 'A customer name is required';
  end if;

  if coalesce(jsonb_typeof(p_items), '') <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'An order must include at least one item';
  end if;

  if jsonb_array_length(p_items) > 100 then
    raise exception 'An order cannot include more than 100 lines';
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

  select
    coalesce(sum(request.quantity * branch_variant.price_kopeks), 0)::integer,
    count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'menu_item_id', item.id,
          'menu_item_variant_id', variant.id,
          'item_name', item_translation.name,
          'item_description', item_translation.description,
          'image_url', coalesce(item.storage_path, item.image_url),
          'variant_name', variant_translation.name,
          'quantity', request.quantity,
          'unit_price_kopeks', branch_variant.price_kopeks,
          'special_instructions',
            nullif(trim(coalesce(request.special_instructions, '')), '')
        )
        order by request.line_number
      ),
      '[]'::jsonb
    )
  into v_subtotal, v_resolved_count, v_resolved_items
  from rows from (
    jsonb_to_recordset(p_items) as (
      menu_item_id uuid,
      menu_item_variant_id uuid,
      quantity integer,
      special_instructions text
    )
  ) with ordinality as request(
    menu_item_id,
    menu_item_variant_id,
    quantity,
    special_instructions,
    line_number
  )
  join public.branch_menu_items branch_item
    on branch_item.branch_id = p_branch_id
   and branch_item.menu_item_id = request.menu_item_id
   and branch_item.is_available
  join public.menu_items item
    on item.id = request.menu_item_id
   and item.is_active
  join public.menu_item_variants variant
    on variant.id = request.menu_item_variant_id
   and variant.menu_item_id = item.id
   and variant.is_active
  join public.branch_menu_item_variants branch_variant
    on branch_variant.branch_id = p_branch_id
   and branch_variant.menu_item_id = item.id
   and branch_variant.menu_item_variant_id = variant.id
   and branch_variant.is_available
  join public.menu_item_translations item_translation
    on item_translation.menu_item_id = item.id
   and item_translation.language_code = 'ru'
  join public.menu_item_variant_translations variant_translation
    on variant_translation.menu_item_variant_id = variant.id
   and variant_translation.language_code = 'ru'
  where request.quantity between 1 and 100;

  if v_resolved_count <> jsonb_array_length(p_items) then
    raise exception 'One or more menu items or size options are unavailable';
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
    menu_item_variant_id,
    item_name,
    item_description,
    image_url,
    variant_name,
    quantity,
    unit_price_kopeks,
    line_total_kopeks,
    special_instructions
  )
  select
    v_order_id,
    resolved.menu_item_id,
    resolved.menu_item_variant_id,
    resolved.item_name,
    resolved.item_description,
    resolved.image_url,
    resolved.variant_name,
    resolved.quantity,
    resolved.unit_price_kopeks,
    resolved.quantity * resolved.unit_price_kopeks,
    resolved.special_instructions
  from jsonb_to_recordset(v_resolved_items) as resolved(
    menu_item_id uuid,
    menu_item_variant_id uuid,
    item_name text,
    item_description text,
    image_url text,
    variant_name text,
    quantity integer,
    unit_price_kopeks integer,
    special_instructions text
  );

  insert into public.order_status_history (
    order_id,
    next_status,
    changed_by,
    reason
  ) values (v_order_id, 'pending', auth.uid(), 'Customer cash order created');

  return v_order_id;
end;
$$;

revoke all on function public.get_branch_menu(uuid, text) from public;
grant execute on function public.get_branch_menu(uuid, text) to authenticated;

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

commit;
