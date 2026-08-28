-- Managers can change only availability for their assigned branch. Prices,
-- menu names, categories and all other branches remain owner-only.
create policy "branch category availability: managers update their branch"
on public.branch_menu_categories for update to authenticated
using (public.can_manage_branch(branch_id))
with check (public.can_manage_branch(branch_id));

create policy "branch menu variants: managers update availability"
on public.branch_menu_item_variants for update to authenticated
using (public.can_manage_branch(branch_id))
with check (public.can_manage_branch(branch_id));

revoke update on public.branch_menu_categories from authenticated;
grant update (is_available, updated_at)
on public.branch_menu_categories to authenticated;

revoke update on public.branch_menu_item_variants from authenticated;
grant update (price_kopeks, is_available, updated_at)
on public.branch_menu_item_variants to authenticated;

-- Column permissions apply to every authenticated account, so enforce the
-- manager restriction again inside the database: managers may change only
-- availability on rows belonging to their assigned branch.
create or replace function public.prevent_manager_menu_variant_edits()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.is_owner() then
    if not public.is_manager_for_branch(old.branch_id)
       or new.branch_id is distinct from old.branch_id
       or new.menu_item_id is distinct from old.menu_item_id
       or new.menu_item_variant_id is distinct from old.menu_item_variant_id
       or new.price_kopeks is distinct from old.price_kopeks then
      raise exception 'Managers can change only availability for their assigned branch';
    end if;
  end if;
  return new;
end;
$$;

create trigger branch_menu_item_variants_limit_manager_edits
before update on public.branch_menu_item_variants
for each row execute function public.prevent_manager_menu_variant_edits();
