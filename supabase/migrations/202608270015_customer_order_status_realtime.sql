-- Enables live status updates for the customer tracking screen. Access to
-- individual order rows remains governed by the existing orders RLS policy.
alter publication supabase_realtime add table public.orders;
