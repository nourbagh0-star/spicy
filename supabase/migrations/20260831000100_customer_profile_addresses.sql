-- Customer profile settings and reusable delivery addresses.
-- Addresses are private to their owner and can be reused once delivery is enabled.

create table public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles (id) on delete cascade,
  label text not null check (char_length(btrim(label)) between 1 and 50),
  address_line text not null check (char_length(btrim(address_line)) between 3 and 300),
  apartment text check (char_length(apartment) <= 50),
  entrance text check (char_length(entrance) <= 50),
  floor text check (char_length(floor) <= 50),
  notes text check (char_length(notes) <= 500),
  latitude numeric(9, 6) check (latitude between -90 and 90),
  longitude numeric(9, 6) check (longitude between -180 and 180),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or (latitude is not null and longitude is not null))
);

create index customer_addresses_customer_created_idx
  on public.customer_addresses (customer_id, created_at);

create unique index customer_addresses_one_default_per_customer_idx
  on public.customer_addresses (customer_id)
  where is_default;

create function public.prepare_customer_address()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
    and old.is_default
    and not new.is_default
    and not exists (
      select 1
      from public.customer_addresses
      where customer_id = new.customer_id
        and id <> old.id
        and is_default
    ) then
    new.is_default := true;
  end if;

  if new.is_default or not exists (
    select 1
    from public.customer_addresses
    where customer_id = new.customer_id
  ) then
    update public.customer_addresses
    set is_default = false
    where customer_id = new.customer_id
      and id is distinct from new.id;
    new.is_default := true;
  end if;

  if tg_op = 'INSERT' and (
    select count(*)
    from public.customer_addresses
    where customer_id = new.customer_id
  ) >= 5 then
    raise exception 'You can save up to five addresses';
  end if;

  return new;
end;
$$;

create trigger customer_addresses_prepare
before insert or update of customer_id, is_default
on public.customer_addresses
for each row execute function public.prepare_customer_address();

create trigger customer_addresses_set_updated_at
before update on public.customer_addresses
for each row execute function public.set_updated_at();

create function public.assign_replacement_default_customer_address()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.is_default then
    update public.customer_addresses
    set is_default = true
    where id = (
      select id
      from public.customer_addresses
      where customer_id = old.customer_id
      order by created_at, id
      limit 1
    );
  end if;
  return old;
end;
$$;

create trigger customer_addresses_assign_replacement_default
after delete on public.customer_addresses
for each row execute function public.assign_replacement_default_customer_address();

alter table public.customer_addresses enable row level security;
revoke all on table public.customer_addresses from anon, authenticated;
grant select, insert, update, delete on table public.customer_addresses to authenticated;

create policy "customer addresses: customers manage their own"
on public.customer_addresses for all to authenticated
using (customer_id = (select auth.uid()))
with check (customer_id = (select auth.uid()));

-- Keep historical restaurant records when a customer deletes an account, but
-- remove the link and personal contact data from those records.
alter table public.orders
  drop constraint if exists orders_customer_id_fkey;
alter table public.orders
  alter column customer_id drop not null;
alter table public.orders
  add constraint orders_customer_id_fkey
  foreign key (customer_id) references public.profiles (id) on delete set null;

alter table public.order_reviews
  drop constraint if exists order_reviews_customer_id_fkey;
alter table public.order_reviews
  alter column customer_id drop not null;
alter table public.order_reviews
  add constraint order_reviews_customer_id_fkey
  foreign key (customer_id) references public.profiles (id) on delete set null;
