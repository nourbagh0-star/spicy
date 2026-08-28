-- A category closed for a branch must be hidden from its customer-facing menu.
-- The owner dashboard can still read and reopen the category through its table.
create or replace function public.get_branch_menu(
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
