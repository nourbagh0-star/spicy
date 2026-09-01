-- The manager driver lookup is a protected RPC endpoint. PostgreSQL grants
-- execute to PUBLIC by default, so explicitly remove anonymous access.
revoke execute on function public.get_branch_drivers_for_assignment(uuid)
from public, anon;

grant execute on function public.get_branch_drivers_for_assignment(uuid)
to authenticated;
