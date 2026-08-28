-- Run this after 202608270017_category_modifiers_customer_menu.sql.
-- It shows every owner-created group and option, including whether it targets
-- one item or a whole category.
select
  coalesce(item_name.name, category_name.name) as applies_to,
  case when grp.menu_item_id is not null then 'one item' else 'whole category' end as scope,
  group_name.name as group_name,
  option_name.name as option_name,
  branch.name as branch_name,
  branch_option.is_available
from public.menu_item_modifier_groups grp
left join public.menu_item_translations item_name
  on item_name.menu_item_id = grp.menu_item_id and item_name.language_code = 'ru'
left join public.menu_category_translations category_name
  on category_name.category_id = grp.menu_category_id and category_name.language_code = 'ru'
join public.menu_item_modifier_group_translations group_name
  on group_name.menu_item_modifier_group_id = grp.id and group_name.language_code = 'ru'
left join public.menu_item_modifier_options option
  on option.menu_item_modifier_group_id = grp.id
left join public.menu_item_modifier_option_translations option_name
  on option_name.menu_item_modifier_option_id = option.id and option_name.language_code = 'ru'
left join public.branch_menu_item_modifier_options branch_option
  on branch_option.menu_item_modifier_option_id = option.id
left join public.branches branch on branch.id = branch_option.branch_id
order by applies_to, group_name, option_name, branch_name;
