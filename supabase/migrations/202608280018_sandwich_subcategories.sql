-- Fixed sandwich subcategories. The owner can reassign an item, while the
-- customer app translates the four stable codes in its own locale.
alter table public.menu_items
  add column if not exists sandwich_type text;

alter table public.menu_items
  drop constraint if exists menu_items_sandwich_type_check;

alter table public.menu_items
  add constraint menu_items_sandwich_type_check
  check (
    sandwich_type is null
    or sandwich_type in ('chicken', 'lamb', 'beef', 'sandwiches')
  );

update public.menu_items as item
set sandwich_type = case
  when substring(item.external_id from '([0-9]+)$')::integer between 1 and 11
    then 'chicken'
  when substring(item.external_id from '([0-9]+)$')::integer between 12 and 13
    then 'lamb'
  when substring(item.external_id from '([0-9]+)$')::integer between 14 and 23
    then 'beef'
  when substring(item.external_id from '([0-9]+)$')::integer between 24 and 27
    then 'sandwiches'
end
where item.category_id = (
  select category.id
  from public.menu_categories as category
  where category.external_id = 'сэндвичи'
)
and item.external_id ~ '-[0-9]+$';

comment on column public.menu_items.sandwich_type is
  'Fixed customer filter: chicken, lamb, beef, or sandwiches. Null outside the sandwich category.';

-- The return shape changes, so PostgreSQL requires the old function to be
-- dropped before it can be recreated with sandwich_type.
drop function if exists public.get_branch_menu(uuid, text);

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
  sandwich_type text,
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
    item.sandwich_type,
    variant.id,
    variant.code,
    variant.sort_order,
    coalesce(variant_locale.name, variant_ru.name),
    branch_variant.price_kopeks
  from public.branches branch
  join public.branch_menu_categories branch_category
    on branch_category.branch_id = branch.id
   and branch_category.is_available
  join public.branch_menu_items branch_item
    on branch_item.branch_id = branch.id
   and branch_item.is_available
  join public.menu_items item
    on item.id = branch_item.menu_item_id
   and item.is_active
  join public.menu_categories category
    on category.id = item.category_id
   and category.is_active
   and category.id = branch_category.category_id
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

revoke all on function public.get_branch_menu(uuid, text) from public;
grant execute on function public.get_branch_menu(uuid, text) to authenticated;

-- Verification: expected counts are chicken 11, lamb 2, beef 10,
-- sandwiches 4, with no unassigned sandwich items.
select item.sandwich_type, count(*)::integer as item_count
from public.menu_items as item
join public.menu_categories as category on category.id = item.category_id
where category.external_id = 'сэндвичи'
group by item.sandwich_type
order by item.sandwich_type;
