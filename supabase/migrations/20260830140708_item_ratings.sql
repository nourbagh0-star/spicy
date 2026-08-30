-- Item ratings are intentionally separate from branch reviews.  A customer may
-- write one branch review (with a comment) and optionally rate each ordered
-- item.  The item-ratings table contains no customer information.
create table public.order_item_ratings (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null unique
    references public.order_items (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default now()
);

alter table public.order_item_ratings enable row level security;

-- Clients never access individual item-rating rows.  They use the controlled
-- RPC below to submit ratings and aggregate-only RPCs to display ratings.
revoke all on table public.order_item_ratings from anon, authenticated;

create or replace function public.get_order_item_rating_choices(
  p_order_id uuid,
  p_language_code text
)
returns table (
  order_item_id uuid,
  item_name text,
  variant_name text,
  image_url text,
  quantity integer,
  already_rated boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if p_language_code not in ('ru', 'en', 'ar') then
    p_language_code := 'ru';
  end if;

  return query
  select
    item.id,
    coalesce(
      item.localization_snapshot -> p_language_code ->> 'item_name',
      item.localization_snapshot -> 'ru' ->> 'item_name',
      item.item_name
    ),
    coalesce(
      item.localization_snapshot -> p_language_code ->> 'variant_name',
      item.localization_snapshot -> 'ru' ->> 'variant_name',
      item.variant_name
    ),
    item.image_url,
    item.quantity,
    rating.id is not null
  from public.orders as order_row
  join public.order_items as item on item.order_id = order_row.id
  left join public.order_item_ratings as rating on rating.order_item_id = item.id
  where order_row.id = p_order_id
    and order_row.customer_id = (select auth.uid())
    and order_row.status = 'completed'
  order by item.id;
end;
$$;

create or replace function public.submit_order_item_ratings(
  p_order_id uuid,
  p_ratings jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  if jsonb_typeof(p_ratings) <> 'array' or jsonb_array_length(p_ratings) = 0 then
    raise exception 'Select at least one item rating';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_ratings) as payload(
      order_item_id uuid,
      rating smallint
    )
    where payload.order_item_id is null
      or payload.rating is null
      or payload.rating not between 1 and 5
  ) then
    raise exception 'Every item rating must be between 1 and 5';
  end if;

  if (
    select count(*) <> count(distinct payload.order_item_id)
    from jsonb_to_recordset(p_ratings) as payload(
      order_item_id uuid,
      rating smallint
    )
  ) then
    raise exception 'Each item can only be rated once';
  end if;

  if not exists (
    select 1
    from public.orders as order_row
    where order_row.id = p_order_id
      and order_row.customer_id = (select auth.uid())
      and order_row.status = 'completed'
  ) then
    raise exception 'Only your completed order can be rated';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_ratings) as payload(
      order_item_id uuid,
      rating smallint
    )
    left join public.order_items as item
      on item.id = payload.order_item_id
     and item.order_id = p_order_id
    where item.id is null
  ) then
    raise exception 'An item does not belong to this order';
  end if;

  if exists (
    select 1
    from public.order_item_ratings as existing_rating
    join jsonb_to_recordset(p_ratings) as payload(
      order_item_id uuid,
      rating smallint
    ) on payload.order_item_id = existing_rating.order_item_id
  ) then
    raise exception 'One or more items have already been rated';
  end if;

  insert into public.order_item_ratings (order_item_id, rating)
  select payload.order_item_id, payload.rating
  from jsonb_to_recordset(p_ratings) as payload(
    order_item_id uuid,
    rating smallint
  );
end;
$$;

create or replace function public.get_branch_menu_item_ratings(
  p_branch_id uuid
)
returns table (
  menu_item_id uuid,
  average_rating numeric,
  rating_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  return query
  select
    item.menu_item_id,
    round(avg(rating.rating)::numeric, 1),
    count(*)
  from public.order_item_ratings as rating
  join public.order_items as item on item.id = rating.order_item_id
  join public.orders as order_row on order_row.id = item.order_id
  where order_row.branch_id = p_branch_id
    and item.menu_item_id is not null
  group by item.menu_item_id;
end;
$$;

create or replace function public.get_branch_rating_summary(
  p_branch_id uuid
)
returns table (
  average_rating numeric,
  review_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  return query
  select
    coalesce(round(avg(review.rating)::numeric, 1), 0::numeric),
    count(*)
  from public.order_reviews as review
  where review.branch_id = p_branch_id;
end;
$$;

revoke execute on function public.get_order_item_rating_choices(uuid, text) from public, anon, authenticated;
revoke execute on function public.submit_order_item_ratings(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.get_branch_menu_item_ratings(uuid) from public, anon, authenticated;
revoke execute on function public.get_branch_rating_summary(uuid) from public, anon, authenticated;

grant execute on function public.get_order_item_rating_choices(uuid, text) to authenticated;
grant execute on function public.submit_order_item_ratings(uuid, jsonb) to authenticated;
grant execute on function public.get_branch_menu_item_ratings(uuid) to authenticated;
grant execute on function public.get_branch_rating_summary(uuid) to authenticated;
