-- Gamified challenges: configurable definitions, per-member progress, bonus rewards

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  type text not null check (type in ('login_streak', 'purchase_count')),
  name text not null,
  description text not null,
  conditions text,
  reward_points integer not null check (reward_points > 0),
  target_count integer not null check (target_count > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger challenges_set_updated_at
before update on public.challenges
for each row
execute function public.set_updated_at();
create table public.member_challenge_progress (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  current_count integer not null default 0 check (current_count >= 0),
  last_activity_date date,
  completed_at timestamptz,
  rewarded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, challenge_id)
);
create index member_challenge_progress_profile_id_idx
  on public.member_challenge_progress (profile_id);
create trigger member_challenge_progress_set_updated_at
before update on public.member_challenge_progress
for each row
execute function public.set_updated_at();
-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_challenge_visible(
  p_challenge public.challenges,
  p_rewarded_at timestamptz
)
returns boolean
language sql
stable
as $$
  select
    p_challenge.is_active
    and (p_challenge.starts_at is null or now() >= p_challenge.starts_at)
    and (
      p_challenge.ends_at is null
      or now() <= p_challenge.ends_at
      or p_rewarded_at is not null
    );
$$;
create or replace function public.award_challenge_bonus(
  p_profile_id uuid,
  p_challenge public.challenges
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_reward_transaction(
    p_profile_id,
    p_challenge.reward_points,
    'bonus',
    'Challenge completed: ' || p_challenge.name,
    null,
    jsonb_build_object(
      'challenge_id', p_challenge.id,
      'challenge_slug', p_challenge.slug,
      'challenge_type', p_challenge.type
    )
  );

  update public.member_challenge_progress
  set
    rewarded_at = now(),
    updated_at = now()
  where profile_id = p_profile_id
    and challenge_id = p_challenge.id
    and rewarded_at is null;
end;
$$;
create or replace function public.process_purchase_challenges(
  p_profile_id uuid,
  p_order_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paid_quantity integer;
  v_challenge public.challenges;
  v_progress public.member_challenge_progress;
  v_new_count integer;
begin
  select coalesce(sum(oi.quantity), 0)::integer
  into v_paid_quantity
  from public.order_items oi
  where oi.order_id = p_order_id
    and oi.unit_price_cents > 0;

  if v_paid_quantity <= 0 then
    return;
  end if;

  for v_challenge in
    select *
    from public.challenges c
    where c.type = 'purchase_count'
      and c.is_active
      and (c.starts_at is null or now() >= c.starts_at)
      and (c.ends_at is null or now() <= c.ends_at)
    order by c.sort_order, c.created_at
  loop
    insert into public.member_challenge_progress (profile_id, challenge_id, current_count)
    values (p_profile_id, v_challenge.id, 0)
    on conflict (profile_id, challenge_id) do nothing;

    select *
    into v_progress
    from public.member_challenge_progress
    where profile_id = p_profile_id
      and challenge_id = v_challenge.id
    for update;

    if v_progress.rewarded_at is not null then
      continue;
    end if;

    v_new_count := least(v_progress.current_count + v_paid_quantity, v_challenge.target_count);

    update public.member_challenge_progress
    set
      current_count = v_new_count,
      completed_at = case
        when v_new_count >= v_challenge.target_count then coalesce(completed_at, now())
        else completed_at
      end,
      updated_at = now()
    where profile_id = p_profile_id
      and challenge_id = v_challenge.id;

    if v_new_count >= v_challenge.target_count and v_progress.rewarded_at is null then
      perform public.award_challenge_bonus(p_profile_id, v_challenge);
    end if;
  end loop;
end;
$$;
create or replace function public.record_daily_login(p_local_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_challenge public.challenges;
  v_progress public.member_challenge_progress;
  v_new_count integer;
begin
  v_profile_id := auth.uid();

  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  for v_challenge in
    select *
    from public.challenges c
    where c.type = 'login_streak'
      and c.is_active
      and (c.starts_at is null or now() >= c.starts_at)
      and (c.ends_at is null or now() <= c.ends_at)
    order by c.sort_order, c.created_at
  loop
    insert into public.member_challenge_progress (profile_id, challenge_id, current_count)
    values (v_profile_id, v_challenge.id, 0)
    on conflict (profile_id, challenge_id) do nothing;

    select *
    into v_progress
    from public.member_challenge_progress
    where profile_id = v_profile_id
      and challenge_id = v_challenge.id
    for update;

    if v_progress.rewarded_at is not null then
      continue;
    end if;

    if v_progress.last_activity_date = p_local_date then
      continue;
    end if;

    if v_progress.last_activity_date = p_local_date - 1 then
      v_new_count := v_progress.current_count + 1;
    elsif v_progress.last_activity_date is null then
      v_new_count := 1;
    else
      v_new_count := 1;
    end if;

    update public.member_challenge_progress
    set
      current_count = v_new_count,
      last_activity_date = p_local_date,
      completed_at = case
        when v_new_count >= v_challenge.target_count then coalesce(completed_at, now())
        else completed_at
      end,
      updated_at = now()
    where profile_id = v_profile_id
      and challenge_id = v_challenge.id;

    if v_new_count >= v_challenge.target_count and v_progress.rewarded_at is null then
      perform public.award_challenge_bonus(v_profile_id, v_challenge);
    end if;
  end loop;
end;
$$;
create or replace function public.get_active_challenges_for_member(p_profile_id uuid)
returns table (
  id uuid,
  slug text,
  type text,
  name text,
  description text,
  conditions text,
  reward_points integer,
  target_count integer,
  starts_at timestamptz,
  ends_at timestamptz,
  sort_order integer,
  current_count integer,
  last_activity_date date,
  completed_at timestamptz,
  rewarded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is distinct from p_profile_id then
    raise exception 'Not authorized to read challenges for this profile';
  end if;

  return query
  select
    c.id,
    c.slug,
    c.type,
    c.name,
    c.description,
    c.conditions,
    c.reward_points,
    c.target_count,
    c.starts_at,
    c.ends_at,
    c.sort_order,
    coalesce(mcp.current_count, 0) as current_count,
    mcp.last_activity_date,
    mcp.completed_at,
    mcp.rewarded_at
  from public.challenges c
  left join public.member_challenge_progress mcp
    on mcp.challenge_id = c.id
   and mcp.profile_id = p_profile_id
  where public.is_challenge_visible(c, mcp.rewarded_at)
  order by c.sort_order, c.created_at;
end;
$$;
-- ---------------------------------------------------------------------------
-- Extend order completion to track purchase challenges
-- ---------------------------------------------------------------------------

create or replace function public.handle_order_completed()
returns trigger
language plpgsql
as $$
declare
  v_earn integer;
  v_redeem integer;
  v_metadata jsonb;
  v_items jsonb;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    if exists (
      select 1
      from public.reward_transactions rt
      where rt.order_id = new.id
        and rt.type in ('earn', 'redeem')
    ) then
      return new;
    end if;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'product_id', oi.product_id,
          'product_name', oi.product_name,
          'quantity', oi.quantity,
          'points_earned', oi.points_earned,
          'points_redeemed', oi.points_redeemed
        )
        order by oi.created_at
      ),
      '[]'::jsonb
    )
    into v_items
    from public.order_items oi
    where oi.order_id = new.id;

    v_earn := public.calculate_order_points(new.id);
    v_redeem := public.calculate_order_redemption_points(new.id);

    v_metadata := jsonb_build_object(
      'rule', case
        when v_earn > 0 and v_redeem > 0 then 'mixed'
        when v_redeem > 0 then 'redemption'
        else 'purchase'
      end,
      'items', v_items,
      'points_earned', v_earn,
      'points_redeemed', v_redeem
    );

    update public.orders
    set
      points_earned = v_earn,
      points_redeemed = v_redeem,
      is_redemption = (v_redeem > 0 and v_earn = 0 and new.total_cents = 0),
      reward_metadata = v_metadata,
      completed_at = coalesce(new.completed_at, now()),
      updated_at = now()
    where id = new.id;

    if v_redeem > 0 then
      perform public.apply_reward_transaction(
        new.profile_id,
        -v_redeem,
        'redeem',
        'Points redeemed for order ' || new.order_number,
        new.id,
        v_metadata
      );
    end if;

    if v_earn > 0 then
      perform public.apply_reward_transaction(
        new.profile_id,
        v_earn,
        'earn',
        'Points earned for order ' || new.order_number,
        new.id,
        v_metadata
      );
    end if;

    perform public.process_purchase_challenges(new.profile_id, new.id);
  end if;

  return new;
end;
$$;
-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.challenges enable row level security;
alter table public.member_challenge_progress enable row level security;
create policy challenges_select_authenticated
  on public.challenges
  for select
  to authenticated
  using (true);
create policy member_challenge_progress_select_own
  on public.member_challenge_progress
  for select
  to authenticated
  using (profile_id = auth.uid());
-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant select on table public.challenges to authenticated;
grant select on table public.member_challenge_progress to authenticated;
grant execute on function public.record_daily_login(date) to authenticated;
grant execute on function public.get_active_challenges_for_member(uuid) to authenticated;
-- ---------------------------------------------------------------------------
-- Seed challenges
-- ---------------------------------------------------------------------------

insert into public.challenges (
  slug,
  type,
  name,
  description,
  conditions,
  reward_points,
  target_count,
  sort_order
)
values
  (
    'ten-day-streak',
    'login_streak',
    '10-Day Streak',
    'Open the app for 10 consecutive days and earn 300 bonus points.',
    'One login counts per calendar day in your local timezone. Missing a day resets your streak to day 1. Bonus points are awarded once when you reach day 10.',
    300,
    10,
    1
  ),
  (
    'ten-purchase-milestone',
    'purchase_count',
    'Regular',
    'Purchase 10 paid items and earn 300 bonus points.',
    'Only paid menu items count toward this challenge. Items claimed with points do not count. Progress updates when your order is marked completed.',
    300,
    10,
    2
  );
