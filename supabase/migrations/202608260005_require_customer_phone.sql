-- Email-confirmed registrations have no session yet, so the profile trigger
-- must copy the phone number from trusted Auth metadata at creation time.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, contact_phone)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'contact_phone', '')), '')
  );
  return new;
end;
$$;

-- No existing customer orders have been imported. Every new order must have
-- a reachable phone number for the branch manager.
alter table public.orders
  add constraint orders_contact_phone_required
  check (nullif(btrim(contact_phone), '') is not null);
