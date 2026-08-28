-- A modifier group targets either one item or every item in one category.
alter table public.menu_item_modifier_groups
  add column menu_category_id uuid references public.menu_categories (id) on delete cascade;

alter table public.menu_item_modifier_groups
  alter column menu_item_id drop not null;

alter table public.menu_item_modifier_groups
  add constraint modifier_group_one_target_check
  check (num_nonnulls(menu_item_id, menu_category_id) = 1);

create index menu_item_modifier_groups_category_active_idx
  on public.menu_item_modifier_groups (menu_category_id, is_active, sort_order)
  where menu_category_id is not null;
