-- Admin challenge management with server-side validation

create or replace function public.validate_challenge_slug(p_slug text)
returns text
language plpgsql
immutable
as $$
declare
  v_slug text;
begin
  v_slug := lower(trim(p_slug));

  if v_slug = '' then
    raise exception 'Slug is required';
  end if;

  if v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'Slug must use lowercase letters, numbers, and hyphens only';
  end if;

  return v_slug;
end;
$$;
create or replace function public.validate_challenge_type(p_type text)
returns text
language plpgsql
immutable
as $$
begin
  if p_type not in ('login_streak', 'purchase_count') then
    raise exception 'Invalid challenge type: %', p_type;
  end if;

  return p_type;
end;
$$;
create or replace function public.list_challenges_admin()
returns setof public.challenges
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select *
  from public.challenges
  order by sort_order, created_at;
end;
$$;
create or replace function public.upsert_challenge_admin(
  p_id uuid default null,
  p_slug text default null,
  p_type text default null,
  p_name text default null,
  p_description text default null,
  p_conditions text default null,
  p_reward_points integer default null,
  p_target_count integer default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_type text;
  v_name text;
  v_description text;
  v_conditions text;
  v_id uuid;
begin
  perform public.assert_admin_access();

  v_slug := public.validate_challenge_slug(p_slug);
  v_type := public.validate_challenge_type(p_type);
  v_name := trim(p_name);
  v_description := trim(p_description);
  v_conditions := nullif(trim(coalesce(p_conditions, '')), '');

  if v_name = '' then
    raise exception 'Name is required';
  end if;

  if v_description = '' then
    raise exception 'Description is required';
  end if;

  if p_reward_points is null or p_reward_points <= 0 then
    raise exception 'Reward points must be greater than zero';
  end if;

  if p_target_count is null or p_target_count <= 0 then
    raise exception 'Target count must be greater than zero';
  end if;

  if p_sort_order is null or p_sort_order < 0 then
    raise exception 'Sort order must be zero or greater';
  end if;

  if p_starts_at is not null and p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception 'End date must be after start date';
  end if;

  if p_id is null then
    insert into public.challenges (
      slug,
      type,
      name,
      description,
      conditions,
      reward_points,
      target_count,
      starts_at,
      ends_at,
      is_active,
      sort_order
    )
    values (
      v_slug,
      v_type,
      v_name,
      v_description,
      v_conditions,
      p_reward_points,
      p_target_count,
      p_starts_at,
      p_ends_at,
      coalesce(p_is_active, true),
      p_sort_order
    )
    returning id into v_id;
  else
    update public.challenges
    set
      slug = v_slug,
      type = v_type,
      name = v_name,
      description = v_description,
      conditions = v_conditions,
      reward_points = p_reward_points,
      target_count = p_target_count,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      is_active = coalesce(p_is_active, true),
      sort_order = p_sort_order,
      updated_at = now()
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'Challenge not found: %', p_id;
    end if;
  end if;

  return v_id;
end;
$$;
grant execute on function public.list_challenges_admin() to authenticated;
grant execute on function public.upsert_challenge_admin(
  uuid,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  timestamptz,
  timestamptz,
  boolean,
  integer
) to authenticated;
