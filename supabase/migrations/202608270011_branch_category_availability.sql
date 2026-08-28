-- Lets an owner/manager close any full menu category for one branch only.
create table public.branch_menu_categories (
  branch_id uuid not null references public.branches (id) on delete cascade,
  category_id uuid not null references public.menu_categories (id) on delete cascade,
  is_available boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (branch_id, category_id)
);

insert into public.branch_menu_categories (branch_id, category_id)
select branch.id, category.id
from public.branches branch cross join public.menu_categories category
on conflict do nothing;

create trigger branch_menu_categories_set_updated_at
before update on public.branch_menu_categories
for each row execute function public.set_updated_at();

alter table public.branch_menu_categories enable row level security;
create policy "branch category availability: users read"
on public.branch_menu_categories for select to authenticated using (true);
create policy "branch category availability: owners manage"
on public.branch_menu_categories for all to authenticated
using (public.is_owner()) with check (public.is_owner());

revoke all on public.branch_menu_categories from anon;
grant select, insert, update, delete on public.branch_menu_categories to authenticated;
