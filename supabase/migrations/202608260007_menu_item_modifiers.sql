-- Owner-configurable additions and removals. Prices are branch-specific and
-- the order function validates every requested option on the server.

create table public.menu_item_modifier_groups (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items (id) on delete cascade,
  code text not null check (btrim(code) <> ''),
  sort_order integer not null default 0,
  minimum_selections integer not null default 0 check (minimum_selections >= 0),
  maximum_selections integer not null default 1 check (maximum_selections >= minimum_selections),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (menu_item_id, code)
);

create table public.menu_item_modifier_group_translations (
  menu_item_modifier_group_id uuid not null references public.menu_item_modifier_groups (id) on delete cascade,
  language_code text not null check (language_code in ('ru', 'en', 'ar')),
  name text not null check (btrim(name) <> ''),
  primary key (menu_item_modifier_group_id, language_code)
);

create table public.menu_item_modifier_options (
  id uuid primary key default gen_random_uuid(),
  menu_item_modifier_group_id uuid not null references public.menu_item_modifier_groups (id) on delete cascade,
  code text not null check (btrim(code) <> ''),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (menu_item_modifier_group_id, code),
  unique (id, menu_item_modifier_group_id)
);

create table public.menu_item_modifier_option_translations (
  menu_item_modifier_option_id uuid not null references public.menu_item_modifier_options (id) on delete cascade,
  language_code text not null check (language_code in ('ru', 'en', 'ar')),
  name text not null check (btrim(name) <> ''),
  primary key (menu_item_modifier_option_id, language_code)
);

create table public.branch_menu_item_modifier_options (
  branch_id uuid not null references public.branches (id) on delete cascade,
  menu_item_modifier_option_id uuid not null references public.menu_item_modifier_options (id) on delete cascade,
  price_kopeks integer not null default 0 check (price_kopeks >= 0),
  is_available boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (branch_id, menu_item_modifier_option_id)
);

create index menu_item_modifier_groups_item_active_idx
  on public.menu_item_modifier_groups (menu_item_id, is_active, sort_order);
create index menu_item_modifier_options_group_active_idx
  on public.menu_item_modifier_options (menu_item_modifier_group_id, is_active, sort_order);

create trigger menu_item_modifier_groups_set_updated_at
before update on public.menu_item_modifier_groups
for each row execute function public.set_updated_at();
create trigger menu_item_modifier_options_set_updated_at
before update on public.menu_item_modifier_options
for each row execute function public.set_updated_at();
create trigger branch_menu_item_modifier_options_set_updated_at
before update on public.branch_menu_item_modifier_options
for each row execute function public.set_updated_at();

alter table public.menu_item_modifier_groups enable row level security;
alter table public.menu_item_modifier_group_translations enable row level security;
alter table public.menu_item_modifier_options enable row level security;
alter table public.menu_item_modifier_option_translations enable row level security;
alter table public.branch_menu_item_modifier_options enable row level security;

create policy "modifier groups: authenticated users read active catalog"
on public.menu_item_modifier_groups for select to authenticated
using (is_active or public.is_owner());
create policy "modifier groups: owners manage"
on public.menu_item_modifier_groups for all to authenticated
using (public.is_owner()) with check (public.is_owner());
create policy "modifier group translations: authenticated users read"
on public.menu_item_modifier_group_translations for select to authenticated
using (true);
create policy "modifier group translations: owners manage"
on public.menu_item_modifier_group_translations for all to authenticated
using (public.is_owner()) with check (public.is_owner());
create policy "modifier options: authenticated users read active catalog"
on public.menu_item_modifier_options for select to authenticated
using (is_active or public.is_owner());
create policy "modifier options: owners manage"
on public.menu_item_modifier_options for all to authenticated
using (public.is_owner()) with check (public.is_owner());
create policy "modifier option translations: authenticated users read"
on public.menu_item_modifier_option_translations for select to authenticated
using (true);
create policy "modifier option translations: owners manage"
on public.menu_item_modifier_option_translations for all to authenticated
using (public.is_owner()) with check (public.is_owner());
create policy "branch modifier options: authenticated users read"
on public.branch_menu_item_modifier_options for select to authenticated
using (is_available or public.is_owner());
create policy "branch modifier options: owners manage"
on public.branch_menu_item_modifier_options for all to authenticated
using (public.is_owner()) with check (public.is_owner());

revoke all on public.menu_item_modifier_groups,
  public.menu_item_modifier_group_translations,
  public.menu_item_modifier_options,
  public.menu_item_modifier_option_translations,
  public.branch_menu_item_modifier_options from anon;
grant select, insert, update, delete on public.menu_item_modifier_groups,
  public.menu_item_modifier_group_translations,
  public.menu_item_modifier_options,
  public.menu_item_modifier_option_translations,
  public.branch_menu_item_modifier_options to authenticated;

alter table public.order_items
  add column modifier_snapshot jsonb not null default '[]'::jsonb
  check (jsonb_typeof(modifier_snapshot) = 'array');

-- Only returns options available at the selected branch; the owner dashboard
-- writes the source tables above, never a client-supplied price.
create function public.get_branch_menu_modifiers(
  p_branch_id uuid,
  p_language_code text default 'ru'
)
returns table (menu_item_id uuid, modifier_groups jsonb)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if coalesce(p_language_code, 'ru') not in ('ru', 'en', 'ar') then
    raise exception 'Unsupported language code';
  end if;
  return query
  select group_row.menu_item_id,
    jsonb_agg(jsonb_build_object(
      'id', group_row.id,
      'name', group_row.name,
      'minimum_selections', group_row.minimum_selections,
      'maximum_selections', group_row.maximum_selections,
      'options', group_row.options
    ) order by group_row.sort_order)
  from (
    select grp.menu_item_id, grp.id, grp.sort_order, grp.minimum_selections,
      grp.maximum_selections, coalesce(grp_locale.name, grp_ru.name) as name,
      coalesce(jsonb_agg(jsonb_build_object(
        'id', option.id,
        'name', coalesce(option_locale.name, option_ru.name),
        'price_kopeks', branch_option.price_kopeks
      ) order by option.sort_order) filter (where option.id is not null), '[]'::jsonb) as options
    from public.menu_item_modifier_groups grp
    join public.menu_item_modifier_group_translations grp_ru
      on grp_ru.menu_item_modifier_group_id = grp.id and grp_ru.language_code = 'ru'
    left join public.menu_item_modifier_group_translations grp_locale
      on grp_locale.menu_item_modifier_group_id = grp.id and grp_locale.language_code = coalesce(p_language_code, 'ru')
    join public.menu_item_modifier_options option
      on option.menu_item_modifier_group_id = grp.id and option.is_active
    join public.branch_menu_item_modifier_options branch_option
      on branch_option.menu_item_modifier_option_id = option.id
     and branch_option.branch_id = p_branch_id and branch_option.is_available
    join public.menu_item_modifier_option_translations option_ru
      on option_ru.menu_item_modifier_option_id = option.id and option_ru.language_code = 'ru'
    left join public.menu_item_modifier_option_translations option_locale
      on option_locale.menu_item_modifier_option_id = option.id and option_locale.language_code = coalesce(p_language_code, 'ru')
    where grp.is_active
    group by grp.menu_item_id, grp.id, grp.sort_order, grp.minimum_selections,
      grp.maximum_selections, grp_locale.name, grp_ru.name
  ) group_row
  group by group_row.menu_item_id;
end;
$$;

revoke all on function public.get_branch_menu_modifiers(uuid, text) from public;
grant execute on function public.get_branch_menu_modifiers(uuid, text) to authenticated;

-- Each selected option is checked against its item and branch. Its current
-- name and price are stored with the order so later owner edits never alter history.
create or replace function public.place_cash_order(
  p_fulfillment public.fulfillment_type, p_branch_id uuid, p_items jsonb,
  p_contact_name text, p_contact_phone text default null,
  p_delivery_address text default null, p_delivery_latitude numeric default null,
  p_delivery_longitude numeric default null, p_pickup_at timestamptz default null,
  p_customer_notes text default null, p_idempotency_key uuid default gen_random_uuid()
)
returns uuid language plpgsql security definer
set search_path = public, extensions
as $$
declare v_order_id uuid; v_subtotal integer; v_resolved_items jsonb; v_resolved_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if nullif(trim(coalesce(p_contact_name, '')), '') is null then raise exception 'A customer name is required'; end if;
  if coalesce(jsonb_typeof(p_items), '') <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'An order must include at least one item'; end if;
  if jsonb_array_length(p_items) > 100 then raise exception 'An order cannot include more than 100 lines'; end if;
  if p_fulfillment <> 'pickup' then raise exception 'Delivery is not available yet'; end if;
  if p_pickup_at is not null and p_pickup_at < now() then raise exception 'A pickup time cannot be in the past'; end if;
  select id into v_order_id from public.orders where customer_id = auth.uid() and idempotency_key = p_idempotency_key;
  if found then return v_order_id; end if;
  if not exists (select 1 from public.branches where id = p_branch_id and is_active) then raise exception 'The selected branch is unavailable'; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_items) as request(modifier_option_ids jsonb)
    where coalesce(jsonb_typeof(modifier_option_ids), 'array') <> 'array'
  ) then raise exception 'Item options must be a list'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as request(menu_item_id uuid, modifier_option_ids jsonb)
    cross join lateral jsonb_array_elements_text(coalesce(request.modifier_option_ids, '[]'::jsonb)) picked(option_id)
    left join public.menu_item_modifier_options option on option.id = picked.option_id::uuid and option.is_active
    left join public.menu_item_modifier_groups grp on grp.id = option.menu_item_modifier_group_id and grp.menu_item_id = request.menu_item_id and grp.is_active
    left join public.branch_menu_item_modifier_options branch_option on branch_option.menu_item_modifier_option_id = option.id and branch_option.branch_id = p_branch_id and branch_option.is_available
    where option.id is null or grp.id is null or branch_option.menu_item_modifier_option_id is null
  ) then raise exception 'One or more requested item options are unavailable'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as request(menu_item_id uuid, modifier_option_ids jsonb)
    join public.menu_item_modifier_groups grp on grp.menu_item_id = request.menu_item_id and grp.is_active
    where (select count(*) from jsonb_array_elements_text(coalesce(request.modifier_option_ids, '[]'::jsonb)) picked(option_id)
      join public.menu_item_modifier_options option on option.id = picked.option_id::uuid
      where option.menu_item_modifier_group_id = grp.id) not between grp.minimum_selections and grp.maximum_selections
  ) then raise exception 'The chosen number of item options is not allowed'; end if;

  select coalesce(sum(resolved.quantity * resolved.unit_price_kopeks), 0)::integer, count(*)::integer,
    coalesce(jsonb_agg(to_jsonb(resolved) order by resolved.line_number), '[]'::jsonb)
  into v_subtotal, v_resolved_count, v_resolved_items
  from (
    select request.line_number, request.quantity, item.id as menu_item_id, variant.id as menu_item_variant_id,
      item_translation.name as item_name, item_translation.description as item_description,
      coalesce(item.storage_path, item.image_url) as image_url, variant_translation.name as variant_name,
      branch_variant.price_kopeks + coalesce(modifiers.price_kopeks, 0) as unit_price_kopeks,
      nullif(trim(coalesce(request.special_instructions, '')), '') as special_instructions,
      coalesce(modifiers.snapshot, '[]'::jsonb) as modifier_snapshot
    from rows from (jsonb_to_recordset(p_items) as (menu_item_id uuid, menu_item_variant_id uuid, quantity integer, special_instructions text, modifier_option_ids jsonb)) with ordinality as request(menu_item_id, menu_item_variant_id, quantity, special_instructions, modifier_option_ids, line_number)
    join public.branch_menu_items branch_item on branch_item.branch_id = p_branch_id and branch_item.menu_item_id = request.menu_item_id and branch_item.is_available
    join public.menu_items item on item.id = request.menu_item_id and item.is_active
    join public.menu_item_variants variant on variant.id = request.menu_item_variant_id and variant.menu_item_id = item.id and variant.is_active
    join public.branch_menu_item_variants branch_variant on branch_variant.branch_id = p_branch_id and branch_variant.menu_item_id = item.id and branch_variant.menu_item_variant_id = variant.id and branch_variant.is_available
    join public.menu_item_translations item_translation on item_translation.menu_item_id = item.id and item_translation.language_code = 'ru'
    join public.menu_item_variant_translations variant_translation on variant_translation.menu_item_variant_id = variant.id and variant_translation.language_code = 'ru'
    left join lateral (
      select coalesce(sum(branch_option.price_kopeks), 0)::integer as price_kopeks,
        coalesce(jsonb_agg(jsonb_build_object('id', option.id, 'name', option_translation.name, 'price_kopeks', branch_option.price_kopeks) order by option.sort_order), '[]'::jsonb) as snapshot
      from jsonb_array_elements_text(coalesce(request.modifier_option_ids, '[]'::jsonb)) picked(option_id)
      join public.menu_item_modifier_options option on option.id = picked.option_id::uuid
      join public.menu_item_modifier_option_translations option_translation on option_translation.menu_item_modifier_option_id = option.id and option_translation.language_code = 'ru'
      join public.branch_menu_item_modifier_options branch_option on branch_option.menu_item_modifier_option_id = option.id and branch_option.branch_id = p_branch_id
    ) modifiers on true
    where request.quantity between 1 and 100
  ) resolved;
  if v_resolved_count <> jsonb_array_length(p_items) then raise exception 'One or more menu items or size options are unavailable'; end if;

  insert into public.orders (customer_id, branch_id, fulfillment, subtotal_kopeks, delivery_fee_kopeks, total_kopeks, contact_name, contact_phone, pickup_at, customer_notes, idempotency_key)
  values (auth.uid(), p_branch_id, p_fulfillment, v_subtotal, 0, v_subtotal, trim(p_contact_name), nullif(trim(coalesce(p_contact_phone, '')), ''), p_pickup_at, nullif(trim(coalesce(p_customer_notes, '')), ''), p_idempotency_key) returning id into v_order_id;
  insert into public.order_items (order_id, menu_item_id, menu_item_variant_id, item_name, item_description, image_url, variant_name, quantity, unit_price_kopeks, line_total_kopeks, special_instructions, modifier_snapshot)
  select v_order_id, resolved.menu_item_id, resolved.menu_item_variant_id, resolved.item_name, resolved.item_description, resolved.image_url, resolved.variant_name, resolved.quantity, resolved.unit_price_kopeks, resolved.quantity * resolved.unit_price_kopeks, resolved.special_instructions, resolved.modifier_snapshot
  from jsonb_to_recordset(v_resolved_items) as resolved(menu_item_id uuid, menu_item_variant_id uuid, item_name text, item_description text, image_url text, variant_name text, quantity integer, unit_price_kopeks integer, special_instructions text, modifier_snapshot jsonb);
  insert into public.order_status_history (order_id, next_status, changed_by, reason) values (v_order_id, 'pending', auth.uid(), 'Customer cash order created');
  return v_order_id;
end;
$$;

revoke all on function public.place_cash_order(public.fulfillment_type, uuid, jsonb, text, text, text, numeric, numeric, timestamptz, text, uuid) from public;
grant execute on function public.place_cash_order(public.fulfillment_type, uuid, jsonb, text, text, text, numeric, numeric, timestamptz, text, uuid) to authenticated;
