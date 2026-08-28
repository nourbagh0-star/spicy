-- Customer reviews are tied to a completed order. This prevents duplicate or
-- fabricated reviews while keeping the public review feed free of customer PII.
create table public.order_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete restrict,
  branch_id uuid not null references public.branches (id) on delete restrict,
  rating smallint not null check (rating between 1 and 5),
  comment text not null check (char_length(btrim(comment)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index order_reviews_branch_created_idx
  on public.order_reviews (branch_id, created_at desc);

alter table public.order_reviews enable row level security;
revoke all on table public.order_reviews from anon, authenticated;
grant select, insert on table public.order_reviews to authenticated;

create policy "order reviews: signed-in customers can read"
on public.order_reviews for select to authenticated
using (true);

create policy "order reviews: customer can review own completed order once"
on public.order_reviews for insert to authenticated
with check (
  customer_id = (select auth.uid())
  and exists (
    select 1
    from public.orders
    where orders.id = order_reviews.order_id
      and orders.customer_id = (select auth.uid())
      and orders.branch_id = order_reviews.branch_id
      and orders.status = 'completed'
  )
);
