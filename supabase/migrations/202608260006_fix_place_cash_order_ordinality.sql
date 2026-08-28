-- Fix PostgreSQL's ROWS FROM syntax when retaining the line order of JSON items.
-- The order function still resolves all prices and availability server-side.

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

  if found then return v_order_id; end if;

  if not exists (
    select 1 from public.branches where id = p_branch_id and is_active
  ) then
    raise exception 'The selected branch is unavailable';
  end if;

  if p_fulfillment = 'delivery' then
    if nullif(trim(coalesce(p_delivery_address, '')), '') is null
      or p_delivery_latitude is null or p_delivery_longitude is null then
      raise exception 'A delivery address and map location are required';
    end if;
    v_delivery_point := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_delivery_longitude, p_delivery_latitude), 4326
    );
    if not exists (
      select 1 from public.delivery_zones
      where branch_id = p_branch_id and is_active
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
    coalesce(jsonb_agg(jsonb_build_object(
      'menu_item_id', item.id,
      'menu_item_variant_id', variant.id,
      'item_name', item_translation.name,
      'item_description', item_translation.description,
      'image_url', coalesce(item.storage_path, item.image_url),
      'variant_name', variant_translation.name,
      'quantity', request.quantity,
      'unit_price_kopeks', branch_variant.price_kopeks,
      'special_instructions', nullif(trim(coalesce(request.special_instructions, '')), '')
    ) order by request.line_number), '[]'::jsonb)
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
  join public.menu_items item on item.id = request.menu_item_id and item.is_active
  join public.menu_item_variants variant
    on variant.id = request.menu_item_variant_id
   and variant.menu_item_id = item.id and variant.is_active
  join public.branch_menu_item_variants branch_variant
    on branch_variant.branch_id = p_branch_id
   and branch_variant.menu_item_id = item.id
   and branch_variant.menu_item_variant_id = variant.id
   and branch_variant.is_available
  join public.menu_item_translations item_translation
    on item_translation.menu_item_id = item.id and item_translation.language_code = 'ru'
  join public.menu_item_variant_translations variant_translation
    on variant_translation.menu_item_variant_id = variant.id
   and variant_translation.language_code = 'ru'
  where request.quantity between 1 and 100;

  if v_resolved_count <> jsonb_array_length(p_items) then
    raise exception 'One or more menu items or size options are unavailable';
  end if;

  insert into public.orders (
    customer_id, branch_id, fulfillment, subtotal_kopeks, delivery_fee_kopeks,
    total_kopeks, contact_name, contact_phone, delivery_address,
    delivery_location, pickup_at, customer_notes, idempotency_key
  ) values (
    auth.uid(), p_branch_id, p_fulfillment, v_subtotal, v_delivery_fee,
    v_subtotal + v_delivery_fee, trim(p_contact_name),
    nullif(trim(coalesce(p_contact_phone, '')), ''),
    case when p_fulfillment = 'delivery' then trim(p_delivery_address) else null end,
    case when p_fulfillment = 'delivery' then v_delivery_point else null end,
    case when p_fulfillment = 'pickup' then p_pickup_at else null end,
    nullif(trim(coalesce(p_customer_notes, '')), ''), p_idempotency_key
  ) returning id into v_order_id;

  insert into public.order_items (
    order_id, menu_item_id, menu_item_variant_id, item_name, item_description,
    image_url, variant_name, quantity, unit_price_kopeks, line_total_kopeks,
    special_instructions
  )
  select v_order_id, resolved.menu_item_id, resolved.menu_item_variant_id,
    resolved.item_name, resolved.item_description, resolved.image_url,
    resolved.variant_name, resolved.quantity, resolved.unit_price_kopeks,
    resolved.quantity * resolved.unit_price_kopeks, resolved.special_instructions
  from jsonb_to_recordset(v_resolved_items) as resolved(
    menu_item_id uuid, menu_item_variant_id uuid, item_name text,
    item_description text, image_url text, variant_name text, quantity integer,
    unit_price_kopeks integer, special_instructions text
  );

  insert into public.order_status_history (order_id, next_status, changed_by, reason)
  values (v_order_id, 'pending', auth.uid(), 'Customer cash order created');

  return v_order_id;
end;
$$;

revoke all on function public.place_cash_order(
  public.fulfillment_type, uuid, jsonb, text, text, text, numeric, numeric,
  timestamptz, text, uuid
) from public;

grant execute on function public.place_cash_order(
  public.fulfillment_type, uuid, jsonb, text, text, text, numeric, numeric,
  timestamptz, text, uuid
) to authenticated;
