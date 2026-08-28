-- The permanent order_number remains unique for accounting. Customers and
-- staff see a shorter order number that restarts from 1 per branch each
-- Moscow business day.
alter table public.orders
  add column business_date date,
  add column daily_order_number integer;

update public.orders
set business_date = timezone('Europe/Moscow', created_at)::date;

with numbered_orders as (
  select id,
    row_number() over (
      partition by branch_id, business_date
      order by created_at, id
    )::integer as new_daily_order_number
  from public.orders
)
update public.orders as order_row
set daily_order_number = numbered_orders.new_daily_order_number
from numbered_orders
where order_row.id = numbered_orders.id;

alter table public.orders
  alter column business_date set not null,
  alter column daily_order_number set not null,
  add constraint orders_daily_order_number_positive
    check (daily_order_number > 0),
  add constraint orders_branch_business_day_number_key
    unique (branch_id, business_date, daily_order_number);

create table public.branch_daily_order_counters (
  branch_id uuid not null references public.branches (id) on delete cascade,
  business_date date not null,
  next_order_number integer not null check (next_order_number > 0),
  primary key (branch_id, business_date)
);

insert into public.branch_daily_order_counters (
  branch_id,
  business_date,
  next_order_number
)
select branch_id, business_date, max(daily_order_number) + 1
from public.orders
group by branch_id, business_date;

alter table public.branch_daily_order_counters enable row level security;
revoke all on public.branch_daily_order_counters from anon, authenticated;

create function public.assign_daily_branch_order_number()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.business_date := timezone('Europe/Moscow', new.created_at)::date;

  insert into public.branch_daily_order_counters (
    branch_id,
    business_date,
    next_order_number
  )
  values (new.branch_id, new.business_date, 2)
  on conflict (branch_id, business_date)
  do update set next_order_number =
    public.branch_daily_order_counters.next_order_number + 1
  returning next_order_number - 1 into new.daily_order_number;

  return new;
end;
$$;

create trigger orders_assign_daily_branch_order_number
before insert on public.orders
for each row execute function public.assign_daily_branch_order_number();

revoke all on function public.assign_daily_branch_order_number() from public;
