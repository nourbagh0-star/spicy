-- Owner-only staff assignment. Customers cannot update their own role.
create or replace function public.owner_assign_manager(
  p_email text,
  p_branch_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  if not public.is_owner() then
    raise exception 'Only the restaurant owner can assign managers';
  end if;

  if not exists (select 1 from public.branches where id = p_branch_id) then
    raise exception 'The selected branch does not exist';
  end if;

  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(p_email));

  if v_user_id is null then
    raise exception 'This person must create an account before becoming a manager';
  end if;

  update public.profiles
  set role = 'manager', assigned_branch_id = p_branch_id
  where id = v_user_id and role <> 'owner';

  if not found then
    raise exception 'The owner account cannot be changed into a manager';
  end if;
end;
$$;

revoke all on function public.owner_assign_manager(text, uuid) from public;
grant execute on function public.owner_assign_manager(text, uuid) to authenticated;
