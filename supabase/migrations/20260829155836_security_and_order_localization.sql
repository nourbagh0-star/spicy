-- Release hardening: lock down public database functions and preserve every
-- customer order in Russian, English, and Arabic.

-- Each order line keeps an immutable display snapshot. This prevents a later
-- menu edit from changing the customer’s historical order.
alter table public.order_items
  add column if not exists localization_snapshot jsonb not null default '{}'::jsonb;

alter table public.order_items
  drop constraint if exists order_items_localization_snapshot_object;

alter table public.order_items
  add constraint order_items_localization_snapshot_object
  check (jsonb_typeof(localization_snapshot) = 'object');

-- Backfill the current order history. Russian keeps the original historical
-- snapshot; English and Arabic use the current menu translations, then fall
-- back to Russian where a translation has not been entered yet.
with resolved_localizations as (
select
  order_item.id,
  jsonb_build_object(
  'ru', jsonb_build_object(
    'item_name', order_item.item_name,
    'item_description', order_item.item_description,
    'variant_name', order_item.variant_name,
    'modifiers', coalesce(order_item.modifier_snapshot, '[]'::jsonb)
  ),
  'en', jsonb_build_object(
    'item_name', coalesce(item_en.name, order_item.item_name),
    'item_description', coalesce(item_en.description, order_item.item_description),
    'variant_name', coalesce(variant_en.name, order_item.variant_name),
    'modifiers', coalesce(modifier_translations.en_snapshot, '[]'::jsonb)
  ),
  'ar', jsonb_build_object(
    'item_name', coalesce(item_ar.name, order_item.item_name),
    'item_description', coalesce(item_ar.description, order_item.item_description),
    'variant_name', coalesce(variant_ar.name, order_item.variant_name),
    'modifiers', coalesce(modifier_translations.ar_snapshot, '[]'::jsonb)
  )
  ) as localization_snapshot
from public.order_items as order_item
join public.menu_items as item on item.id = order_item.menu_item_id
left join public.menu_item_translations as item_en
  on item_en.menu_item_id = item.id and item_en.language_code = 'en'
left join public.menu_item_translations as item_ar
  on item_ar.menu_item_id = item.id and item_ar.language_code = 'ar'
left join public.menu_item_variant_translations as variant_en
  on variant_en.menu_item_variant_id = order_item.menu_item_variant_id
 and variant_en.language_code = 'en'
left join public.menu_item_variant_translations as variant_ar
  on variant_ar.menu_item_variant_id = order_item.menu_item_variant_id
 and variant_ar.language_code = 'ar'
left join lateral (
  select
    jsonb_agg(
      jsonb_build_object(
        'id', picked.option_data ->> 'id',
        'name', coalesce(option_en.name, picked.option_data ->> 'name', ''),
        'price_kopeks', coalesce((picked.option_data ->> 'price_kopeks')::integer, 0)
      ) order by option.sort_order
    ) as en_snapshot,
    jsonb_agg(
      jsonb_build_object(
        'id', picked.option_data ->> 'id',
        'name', coalesce(option_ar.name, picked.option_data ->> 'name', ''),
        'price_kopeks', coalesce((picked.option_data ->> 'price_kopeks')::integer, 0)
      ) order by option.sort_order
    ) as ar_snapshot
  from jsonb_array_elements(coalesce(order_item.modifier_snapshot, '[]'::jsonb))
    as picked(option_data)
  left join public.menu_item_modifier_options as option
    on option.id = nullif(picked.option_data ->> 'id', '')::uuid
  left join public.menu_item_modifier_option_translations as option_en
    on option_en.menu_item_modifier_option_id = option.id
   and option_en.language_code = 'en'
  left join public.menu_item_modifier_option_translations as option_ar
    on option_ar.menu_item_modifier_option_id = option.id
   and option_ar.language_code = 'ar'
) as modifier_translations on true
)
update public.order_items as order_item
set localization_snapshot = resolved_localizations.localization_snapshot
from resolved_localizations
where resolved_localizations.id = order_item.id;

comment on column public.order_items.localization_snapshot is
  'Immutable Russian, English, and Arabic display data captured for the order line.';

-- New orders capture all three display languages at checkout. Prices and
-- availability remain server-validated; client text is never trusted.
create or replace function public.place_cash_order(
  p_fulfillment public.fulfillment_type, p_branch_id uuid, p_items jsonb,
  p_contact_name text, p_contact_phone text default null,
  p_delivery_address text default null, p_delivery_latitude numeric default null,
  p_delivery_longitude numeric default null, p_pickup_at timestamptz default null,
  p_customer_notes text default null, p_idempotency_key uuid default extensions.gen_random_uuid()
)
returns uuid language plpgsql security definer
set search_path = ''
as $$
declare
  v_order_id uuid;
  v_subtotal integer;
  v_resolved_items jsonb;
  v_resolved_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if nullif(trim(coalesce(p_contact_name, '')), '') is null then raise exception 'A customer name is required'; end if;
  if coalesce(jsonb_typeof(p_items), '') <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'An order must include at least one item'; end if;
  if jsonb_array_length(p_items) > 100 then raise exception 'An order cannot include more than 100 lines'; end if;
  if p_fulfillment <> 'pickup' then raise exception 'Delivery is not available yet'; end if;
  if p_pickup_at is not null and p_pickup_at < now() then raise exception 'A pickup time cannot be in the past'; end if;
  if not exists (select 1 from public.branches where id = p_branch_id and is_active) then raise exception 'The selected branch is unavailable'; end if;

  select id into v_order_id
  from public.orders
  where customer_id = auth.uid() and idempotency_key = p_idempotency_key;
  if found then return v_order_id; end if;

  if exists (
    select 1 from jsonb_to_recordset(p_items) as request(modifier_option_ids jsonb)
    where coalesce(jsonb_typeof(modifier_option_ids), 'array') <> 'array'
  ) then raise exception 'Item options must be a list'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as request(menu_item_id uuid, modifier_option_ids jsonb)
    join public.menu_items as item on item.id = request.menu_item_id
    cross join lateral jsonb_array_elements_text(coalesce(request.modifier_option_ids, '[]'::jsonb)) as picked(option_id)
    where not exists (
      select 1
      from public.menu_item_modifier_options as option
      join public.menu_item_modifier_groups as modifier_group
        on modifier_group.id = option.menu_item_modifier_group_id and modifier_group.is_active
      join public.branch_menu_item_modifier_options as branch_option
        on branch_option.menu_item_modifier_option_id = option.id
       and branch_option.branch_id = p_branch_id
       and branch_option.is_available
      where option.id = picked.option_id::uuid
        and option.is_active
        and (modifier_group.menu_item_id = item.id or modifier_group.menu_category_id = item.category_id)
    )
  ) then raise exception 'One or more requested item options are unavailable'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as request(menu_item_id uuid, modifier_option_ids jsonb)
    join public.menu_items as item on item.id = request.menu_item_id
    join public.menu_item_modifier_groups as modifier_group
      on (modifier_group.menu_item_id = item.id or modifier_group.menu_category_id = item.category_id)
     and modifier_group.is_active
    where (
      select count(*)
      from jsonb_array_elements_text(coalesce(request.modifier_option_ids, '[]'::jsonb)) as picked(option_id)
      join public.menu_item_modifier_options as option on option.id = picked.option_id::uuid
      where option.menu_item_modifier_group_id = modifier_group.id
    ) not between modifier_group.minimum_selections and modifier_group.maximum_selections
  ) then raise exception 'The chosen number of item options is not allowed'; end if;

  select
    coalesce(sum(resolved.quantity * resolved.unit_price_kopeks), 0)::integer,
    count(*)::integer,
    coalesce(jsonb_agg(to_jsonb(resolved) order by resolved.line_number), '[]'::jsonb)
  into v_subtotal, v_resolved_count, v_resolved_items
  from (
    select
      request.line_number,
      request.quantity,
      item.id as menu_item_id,
      variant.id as menu_item_variant_id,
      item_ru.name as item_name,
      item_ru.description as item_description,
      coalesce(item.storage_path, item.image_url) as image_url,
      variant_ru.name as variant_name,
      branch_variant.price_kopeks + coalesce(modifiers.price_kopeks, 0) as unit_price_kopeks,
      nullif(trim(coalesce(request.special_instructions, '')), '') as special_instructions,
      coalesce(modifiers.ru_snapshot, '[]'::jsonb) as modifier_snapshot,
      jsonb_build_object(
        'ru', jsonb_build_object(
          'item_name', item_ru.name,
          'item_description', item_ru.description,
          'variant_name', variant_ru.name,
          'modifiers', coalesce(modifiers.ru_snapshot, '[]'::jsonb)
        ),
        'en', jsonb_build_object(
          'item_name', coalesce(item_en.name, item_ru.name),
          'item_description', coalesce(item_en.description, item_ru.description),
          'variant_name', coalesce(variant_en.name, variant_ru.name),
          'modifiers', coalesce(modifiers.en_snapshot, modifiers.ru_snapshot, '[]'::jsonb)
        ),
        'ar', jsonb_build_object(
          'item_name', coalesce(item_ar.name, item_ru.name),
          'item_description', coalesce(item_ar.description, item_ru.description),
          'variant_name', coalesce(variant_ar.name, variant_ru.name),
          'modifiers', coalesce(modifiers.ar_snapshot, modifiers.ru_snapshot, '[]'::jsonb)
        )
      ) as localization_snapshot
    from rows from (jsonb_to_recordset(p_items) as (
      menu_item_id uuid, menu_item_variant_id uuid, quantity integer,
      special_instructions text, modifier_option_ids jsonb
    )) with ordinality as request(menu_item_id, menu_item_variant_id, quantity, special_instructions, modifier_option_ids, line_number)
    join public.branch_menu_items as branch_item
      on branch_item.branch_id = p_branch_id
     and branch_item.menu_item_id = request.menu_item_id
     and branch_item.is_available
    join public.menu_items as item on item.id = request.menu_item_id and item.is_active
    join public.menu_item_variants as variant
      on variant.id = request.menu_item_variant_id
     and variant.menu_item_id = item.id
     and variant.is_active
    join public.branch_menu_item_variants as branch_variant
      on branch_variant.branch_id = p_branch_id
     and branch_variant.menu_item_id = item.id
     and branch_variant.menu_item_variant_id = variant.id
     and branch_variant.is_available
    join public.menu_item_translations as item_ru
      on item_ru.menu_item_id = item.id and item_ru.language_code = 'ru'
    left join public.menu_item_translations as item_en
      on item_en.menu_item_id = item.id and item_en.language_code = 'en'
    left join public.menu_item_translations as item_ar
      on item_ar.menu_item_id = item.id and item_ar.language_code = 'ar'
    join public.menu_item_variant_translations as variant_ru
      on variant_ru.menu_item_variant_id = variant.id and variant_ru.language_code = 'ru'
    left join public.menu_item_variant_translations as variant_en
      on variant_en.menu_item_variant_id = variant.id and variant_en.language_code = 'en'
    left join public.menu_item_variant_translations as variant_ar
      on variant_ar.menu_item_variant_id = variant.id and variant_ar.language_code = 'ar'
    left join lateral (
      select
        coalesce(sum(branch_option.price_kopeks), 0)::integer as price_kopeks,
        coalesce(jsonb_agg(jsonb_build_object('id', option.id, 'name', option_ru.name, 'price_kopeks', branch_option.price_kopeks) order by option.sort_order), '[]'::jsonb) as ru_snapshot,
        coalesce(jsonb_agg(jsonb_build_object('id', option.id, 'name', coalesce(option_en.name, option_ru.name), 'price_kopeks', branch_option.price_kopeks) order by option.sort_order), '[]'::jsonb) as en_snapshot,
        coalesce(jsonb_agg(jsonb_build_object('id', option.id, 'name', coalesce(option_ar.name, option_ru.name), 'price_kopeks', branch_option.price_kopeks) order by option.sort_order), '[]'::jsonb) as ar_snapshot
      from jsonb_array_elements_text(coalesce(request.modifier_option_ids, '[]'::jsonb)) as picked(option_id)
      join public.menu_item_modifier_options as option on option.id = picked.option_id::uuid
      join public.menu_item_modifier_option_translations as option_ru
        on option_ru.menu_item_modifier_option_id = option.id and option_ru.language_code = 'ru'
      left join public.menu_item_modifier_option_translations as option_en
        on option_en.menu_item_modifier_option_id = option.id and option_en.language_code = 'en'
      left join public.menu_item_modifier_option_translations as option_ar
        on option_ar.menu_item_modifier_option_id = option.id and option_ar.language_code = 'ar'
      join public.branch_menu_item_modifier_options as branch_option
        on branch_option.menu_item_modifier_option_id = option.id and branch_option.branch_id = p_branch_id
    ) as modifiers on true
    where request.quantity between 1 and 100
  ) as resolved;

  if v_resolved_count <> jsonb_array_length(p_items) then
    raise exception 'One or more menu items or size options are unavailable';
  end if;

  insert into public.orders (
    customer_id, branch_id, fulfillment, subtotal_kopeks, delivery_fee_kopeks,
    total_kopeks, contact_name, contact_phone, pickup_at, customer_notes, idempotency_key
  ) values (
    auth.uid(), p_branch_id, p_fulfillment, v_subtotal, 0, v_subtotal,
    trim(p_contact_name), nullif(trim(coalesce(p_contact_phone, '')), ''),
    p_pickup_at, nullif(trim(coalesce(p_customer_notes, '')), ''), p_idempotency_key
  ) returning id into v_order_id;

  insert into public.order_items (
    order_id, menu_item_id, menu_item_variant_id, item_name, item_description,
    image_url, variant_name, quantity, unit_price_kopeks, line_total_kopeks,
    special_instructions, modifier_snapshot, localization_snapshot
  )
  select
    v_order_id, resolved.menu_item_id, resolved.menu_item_variant_id,
    resolved.item_name, resolved.item_description, resolved.image_url,
    resolved.variant_name, resolved.quantity, resolved.unit_price_kopeks,
    resolved.quantity * resolved.unit_price_kopeks, resolved.special_instructions,
    resolved.modifier_snapshot, resolved.localization_snapshot
  from jsonb_to_recordset(v_resolved_items) as resolved(
    menu_item_id uuid, menu_item_variant_id uuid, item_name text,
    item_description text, image_url text, variant_name text, quantity integer,
    unit_price_kopeks integer, special_instructions text,
    modifier_snapshot jsonb, localization_snapshot jsonb
  );

  insert into public.order_status_history (order_id, next_status, changed_by, reason)
  values (v_order_id, 'pending', auth.uid(), 'Customer cash order created');

  return v_order_id;
end;
$$;

-- SECURITY DEFINER routines must have a locked search path and explicit
-- execute permissions. Helper routines stay usable by RLS policies, but none
-- are available to anonymous requests.
alter function public.can_manage_branch(uuid) set search_path = '';
alter function public.cancel_pending_order(uuid, text) set search_path = '';
alter function public.delivery_fee_kopeks() set search_path = '';
alter function public.eligible_branches_for_location(numeric, numeric) set search_path = '';
alter function public.get_branch_menu(uuid, text) set search_path = '';
alter function public.get_branch_menu_modifiers(uuid, text) set search_path = '';
alter function public.handle_new_user() set search_path = '';
alter function public.is_manager_for_branch(uuid) set search_path = '';
alter function public.is_owner() set search_path = '';
alter function public.is_valid_order_transition(public.order_status, public.order_status) set search_path = '';
alter function public.manager_update_order_status(uuid, public.order_status, text, text) set search_path = '';
alter function public.owner_assign_manager(text, uuid) set search_path = '';

revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

grant execute on function public.is_owner() to authenticated;
grant execute on function public.is_manager_for_branch(uuid) to authenticated;
grant execute on function public.can_manage_branch(uuid) to authenticated;
grant execute on function public.get_branch_menu(uuid, text) to authenticated;
grant execute on function public.get_branch_menu_modifiers(uuid, text) to authenticated;
grant execute on function public.place_cash_order(public.fulfillment_type, uuid, jsonb, text, text, text, numeric, numeric, timestamptz, text, uuid) to authenticated;
grant execute on function public.cancel_pending_order(uuid, text) to authenticated;
grant execute on function public.manager_update_order_status(uuid, public.order_status, text, text) to authenticated;
grant execute on function public.owner_assign_manager(text, uuid) to authenticated;
