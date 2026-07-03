-- Step challenges: daily step tracking, step_streak / step_total types, reminders

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

alter table public.challenges
  add column if not exists daily_step_target integer
    check (daily_step_target is null or daily_step_target > 0);
alter table public.challenges
  drop constraint if exists challenges_type_check;
alter table public.challenges
  add constraint challenges_type_check
  check (type in ('login_streak', 'purchase_count', 'step_streak', 'step_total'));
create table if not exists public.member_daily_steps (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  step_date date not null,
  step_count integer not null default 0 check (step_count >= 0),
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, step_date)
);
create index if not exists member_daily_steps_profile_date_idx
  on public.member_daily_steps (profile_id, step_date desc);
create trigger member_daily_steps_set_updated_at
before update on public.member_daily_steps
for each row
execute function public.set_updated_at();
alter publication supabase_realtime add table public.member_daily_steps;
-- ---------------------------------------------------------------------------
-- Validation helpers
-- ---------------------------------------------------------------------------

create or replace function public.validate_challenge_type(p_type text)
returns text
language plpgsql
immutable
as $$
begin
  if p_type not in ('login_streak', 'purchase_count', 'step_streak', 'step_total') then
    raise exception 'Invalid challenge type: %', p_type;
  end if;

  return p_type;
end;
$$;
create or replace function public.validate_step_challenge_config(
  p_type text,
  p_target_count integer,
  p_daily_step_target integer
)
returns void
language plpgsql
immutable
as $$
begin
  if p_type = 'step_streak' then
    if p_daily_step_target is null or p_daily_step_target <= 0 then
      raise exception 'Daily step target is required for step streak challenges';
    end if;
  elsif p_type = 'step_total' then
    if p_daily_step_target is not null then
      raise exception 'Daily step target must be null for step total challenges';
    end if;
  end if;
end;
$$;
-- ---------------------------------------------------------------------------
-- Admin challenge RPCs
-- ---------------------------------------------------------------------------

drop function if exists public.upsert_challenge_admin(
  uuid, text, text, text, text, text, integer, integer, timestamptz, timestamptz, boolean, integer
);
drop function if exists public.upsert_challenge_admin(
  uuid, text, text, text, text, text, integer, integer, integer, timestamptz, timestamptz, boolean, integer
);
create or replace function public.upsert_challenge_admin(
  p_id uuid default null,
  p_slug text default null,
  p_type text default null,
  p_name text default null,
  p_description text default null,
  p_conditions text default null,
  p_reward_points integer default null,
  p_target_count integer default null,
  p_daily_step_target integer default null,
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
  perform public.validate_step_challenge_config(v_type, p_target_count, p_daily_step_target);
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
      daily_step_target,
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
      p_daily_step_target,
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
      daily_step_target = p_daily_step_target,
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
-- ---------------------------------------------------------------------------
-- Member challenge listing
-- ---------------------------------------------------------------------------

drop function if exists public.get_active_challenges_for_member(uuid);
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
  daily_step_target integer,
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
    c.daily_step_target,
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
-- Step sync + challenge progress
-- ---------------------------------------------------------------------------

create or replace function public.process_step_streak_challenges(
  p_profile_id uuid,
  p_local_date date,
  p_step_count integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.challenges;
  v_progress public.member_challenge_progress;
  v_new_count integer;
begin
  for v_challenge in
    select *
    from public.challenges c
    where c.type = 'step_streak'
      and c.is_active
      and (c.starts_at is null or now() >= c.starts_at)
      and (c.ends_at is null or now() <= c.ends_at)
    order by c.sort_order, c.created_at
  loop
    if p_step_count < v_challenge.daily_step_target then
      continue;
    end if;

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
    where profile_id = p_profile_id
      and challenge_id = v_challenge.id;

    if v_new_count >= v_challenge.target_count and v_progress.rewarded_at is null then
      perform public.award_challenge_bonus(p_profile_id, v_challenge);
    end if;
  end loop;
end;
$$;
create or replace function public.process_step_total_challenges(
  p_profile_id uuid,
  p_step_delta integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_challenge public.challenges;
  v_progress public.member_challenge_progress;
  v_new_count integer;
begin
  if p_step_delta <= 0 then
    return;
  end if;

  for v_challenge in
    select *
    from public.challenges c
    where c.type = 'step_total'
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

    v_new_count := least(v_progress.current_count + p_step_delta, v_challenge.target_count);

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
create or replace function public.record_daily_steps(
  p_local_date date,
  p_step_count integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_old_count integer := 0;
  v_new_count integer;
  v_delta integer;
  v_max_daily integer := 100000;
begin
  v_profile_id := auth.uid();

  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_step_count is null or p_step_count < 0 then
    raise exception 'Step count must be zero or greater';
  end if;

  v_new_count := least(p_step_count, v_max_daily);

  select mds.step_count
  into v_old_count
  from public.member_daily_steps mds
  where mds.profile_id = v_profile_id
    and mds.step_date = p_local_date;

  v_old_count := coalesce(v_old_count, 0);
  v_delta := greatest(v_new_count - v_old_count, 0);

  insert into public.member_daily_steps (profile_id, step_date, step_count, synced_at)
  values (v_profile_id, p_local_date, v_new_count, now())
  on conflict (profile_id, step_date) do update
  set
    step_count = greatest(public.member_daily_steps.step_count, excluded.step_count),
    synced_at = now(),
    updated_at = now();

  select mds.step_count
  into v_new_count
  from public.member_daily_steps mds
  where mds.profile_id = v_profile_id
    and mds.step_date = p_local_date;

  v_delta := greatest(v_new_count - v_old_count, 0);

  perform public.process_step_streak_challenges(v_profile_id, p_local_date, v_new_count);
  perform public.process_step_total_challenges(v_profile_id, v_delta);
end;
$$;
create or replace function public.get_member_daily_steps(p_days integer default 7)
returns table (
  step_date date,
  step_count integer,
  synced_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_days integer := greatest(least(coalesce(p_days, 7), 30), 1);
  v_start date := public.get_london_date() - (v_days - 1);
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select mds.step_date, mds.step_count, mds.synced_at
  from public.member_daily_steps mds
  where mds.profile_id = v_profile_id
    and mds.step_date >= v_start
  order by mds.step_date desc;
end;
$$;
create or replace function public.get_member_steps_today()
returns table (
  step_date date,
  step_count integer,
  synced_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_today date := public.get_london_date();
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select v_today, coalesce(mds.step_count, 0), mds.synced_at
  from (select 1) s
  left join public.member_daily_steps mds
    on mds.profile_id = v_profile_id
   and mds.step_date = v_today;
end;
$$;
-- ---------------------------------------------------------------------------
-- App settings seeds
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value_integer, description)
values
  ('step_daily_goal_default', 10000, 'Default daily step goal shown in UI'),
  ('step_encouragement_low_threshold', 3000, 'Below this step count, show low-activity encouragement')
on conflict (key) do nothing;
insert into public.app_settings (key, value_integer, value_text, description)
values
  ('step_low_activity_title', 0, 'Keep moving', 'Step reminder title when daily goal not met'),
  ('step_low_activity_body', 0, 'You''re at {steps_today} steps — {steps_remaining} to go for today''s goal. A short walk gets you closer to your reward!', 'Step reminder body'),
  ('step_near_daily_goal_title', 0, 'Almost at today''s goal', 'Step reminder when close to daily target'),
  ('step_near_daily_goal_body', 0, 'Just {steps_remaining} steps left today — you''ve got this!', 'Step reminder body near goal'),
  ('step_streak_at_risk_title', 0, 'Don''t break your walk streak', 'Step streak evening reminder title'),
  ('step_streak_at_risk_body', 0, 'Hit {daily_step_target} steps today to keep your streak alive and earn {reward_points} points.', 'Step streak evening reminder body'),
  ('step_sync_reminder_title', 0, 'Sync your steps', 'Morning reminder when steps were not synced'),
  ('step_sync_reminder_body', 0, 'Open Groundup to sync yesterday''s steps and keep your walking challenge on track.', 'Morning sync reminder body')
on conflict (key) do nothing;
-- ---------------------------------------------------------------------------
-- Seed step challenges
-- ---------------------------------------------------------------------------

insert into public.challenges (
  slug,
  type,
  name,
  description,
  conditions,
  reward_points,
  target_count,
  daily_step_target,
  sort_order
)
values
  (
    'ten-day-10k-walk',
    'step_streak',
    '10-Day 10K Walk',
    'Walk 10,000 steps a day for 10 days and earn 500 bonus points — enough for a complimentary drink.',
    'Steps sync from Apple Health or Health Connect. Each London calendar day counts once when you reach 10,000 steps. Missing a day resets your streak to day 1.',
    500,
    10,
    10000,
    3
  ),
  (
    'seven-day-5k',
    'step_streak',
    '7-Day 5K Starter',
    'Ease in with 5,000 steps a day for 7 days and earn 300 bonus points.',
    'Steps sync automatically when you open the app. Each day counts once when you reach 5,000 steps in London time.',
    300,
    7,
    5000,
    4
  ),
  (
    'fifty-k-milestone',
    'step_total',
    '50K Step Milestone',
    'Walk a total of 50,000 steps and earn 350 bonus points toward your next treat.',
    'Every synced step counts toward your total. Progress updates when you open the app with health access enabled.',
    350,
    50000,
    null,
    5
  )
on conflict (slug) do nothing;
-- ---------------------------------------------------------------------------
-- Notification settings extensions
-- ---------------------------------------------------------------------------

drop function if exists public.get_notification_settings();
create or replace function public.get_notification_settings()
returns table (
  birthday_coupon_enabled integer,
  birthday_coupon_discount_percent integer,
  birthday_coupon_validity_days integer,
  birthday_coupon_min_order_cents integer,
  challenge_reminder_enabled integer,
  challenge_streak_reminder_hour integer,
  challenge_inactive_days_threshold integer,
  order_notify_ready integer,
  order_notify_cancelled integer,
  order_notify_confirmed integer,
  birthday_notification_title text,
  birthday_notification_body text,
  birthday_coupon_title text,
  birthday_coupon_description text,
  challenge_streak_at_risk_title text,
  challenge_streak_at_risk_body text,
  challenge_near_completion_title text,
  challenge_near_completion_body text,
  challenge_inactive_title text,
  challenge_inactive_body text,
  challenge_streak_broken_title text,
  challenge_streak_broken_body text,
  challenge_ending_soon_title text,
  challenge_ending_soon_body text,
  step_low_activity_title text,
  step_low_activity_body text,
  step_near_daily_goal_title text,
  step_near_daily_goal_body text,
  step_streak_at_risk_title text,
  step_streak_at_risk_body text,
  step_sync_reminder_title text,
  step_sync_reminder_body text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    public.get_app_setting_integer('birthday_coupon_enabled', 1),
    public.get_app_setting_integer('birthday_coupon_discount_percent', 15),
    public.get_app_setting_integer('birthday_coupon_validity_days', 14),
    public.get_app_setting_integer('birthday_coupon_min_order_cents', 0),
    public.get_app_setting_integer('challenge_reminder_enabled', 1),
    public.get_app_setting_integer('challenge_streak_reminder_hour', 20),
    public.get_app_setting_integer('challenge_inactive_days_threshold', 3),
    public.get_app_setting_integer('order_notify_ready', 1),
    public.get_app_setting_integer('order_notify_cancelled', 1),
    public.get_app_setting_integer('order_notify_confirmed', 0),
    public.get_app_setting_text('birthday_notification_title', 'Happy Birthday, {first_name}!'),
    public.get_app_setting_text('birthday_notification_body', 'We''ve added {discount}% off to your wallet — treat yourself today.'),
    public.get_app_setting_text('birthday_coupon_title', 'Birthday treat'),
    public.get_app_setting_text('birthday_coupon_description', 'Your birthday gift from Ground Up'),
    public.get_app_setting_text('challenge_streak_at_risk_title', 'Keep your streak going'),
    public.get_app_setting_text('challenge_streak_at_risk_body', 'Your {streak}-day streak is waiting — one quick visit keeps it alive.'),
    public.get_app_setting_text('challenge_near_completion_title', 'Almost there!'),
    public.get_app_setting_text('challenge_near_completion_body', 'One more step and you unlock {reward_points} points!'),
    public.get_app_setting_text('challenge_inactive_title', 'We miss you'),
    public.get_app_setting_text('challenge_inactive_body', 'You''re {remaining} steps from {reward_points} points. Pop in when you can.'),
    public.get_app_setting_text('challenge_streak_broken_title', 'Fresh start'),
    public.get_app_setting_text('challenge_streak_broken_body', 'No worries — every streak starts with day one. Ready when you are.'),
    public.get_app_setting_text('challenge_ending_soon_title', 'Time is running out'),
    public.get_app_setting_text('challenge_ending_soon_body', '{challenge_name} ends in 2 days — still time to finish!'),
    public.get_app_setting_text('step_low_activity_title', 'Keep moving'),
    public.get_app_setting_text('step_low_activity_body', 'You''re at {steps_today} steps — {steps_remaining} to go for today''s goal. A short walk gets you closer to your reward!'),
    public.get_app_setting_text('step_near_daily_goal_title', 'Almost at today''s goal'),
    public.get_app_setting_text('step_near_daily_goal_body', 'Just {steps_remaining} steps left today — you''ve got this!'),
    public.get_app_setting_text('step_streak_at_risk_title', 'Don''t break your walk streak'),
    public.get_app_setting_text('step_streak_at_risk_body', 'Hit {daily_step_target} steps today to keep your streak alive and earn {reward_points} points.'),
    public.get_app_setting_text('step_sync_reminder_title', 'Sync your steps'),
    public.get_app_setting_text('step_sync_reminder_body', 'Open Groundup to sync yesterday''s steps and keep your walking challenge on track.');
$$;
create or replace function public.update_notification_setting_text(
  p_key text,
  p_value_text text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  if p_key not in (
    'birthday_notification_title',
    'birthday_notification_body',
    'birthday_coupon_title',
    'birthday_coupon_description',
    'challenge_streak_at_risk_title',
    'challenge_streak_at_risk_body',
    'challenge_near_completion_title',
    'challenge_near_completion_body',
    'challenge_inactive_title',
    'challenge_inactive_body',
    'challenge_streak_broken_title',
    'challenge_streak_broken_body',
    'challenge_ending_soon_title',
    'challenge_ending_soon_body',
    'step_low_activity_title',
    'step_low_activity_body',
    'step_near_daily_goal_title',
    'step_near_daily_goal_body',
    'step_streak_at_risk_title',
    'step_streak_at_risk_body',
    'step_sync_reminder_title',
    'step_sync_reminder_body'
  ) then
    raise exception 'Unknown notification setting text key: %', p_key;
  end if;

  update public.app_settings
  set value_text = nullif(trim(p_value_text), ''), updated_at = now()
  where key = p_key;

  if not found then
    raise exception 'App setting not found: %', p_key;
  end if;
end;
$$;
-- ---------------------------------------------------------------------------
-- Challenge reminders (step-aware)
-- ---------------------------------------------------------------------------

create or replace function public.process_challenge_reminders(p_pass text default 'morning')
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enabled integer;
  v_inactive_days integer;
  v_today date := public.get_london_date();
  v_count integer := 0;
  v_row record;
  v_title text;
  v_body text;
  v_remaining integer;
  v_steps_today integer;
  v_steps_remaining integer;
  v_near_threshold integer := 500;
begin
  v_enabled := public.get_app_setting_integer('challenge_reminder_enabled', 1);
  if v_enabled = 0 then
    return 0;
  end if;

  v_inactive_days := public.get_app_setting_integer('challenge_inactive_days_threshold', 3);

  for v_row in
    select
      p.id as profile_id,
      p.first_name,
      c.id as challenge_id,
      c.name as challenge_name,
      c.type as challenge_type,
      c.reward_points,
      c.target_count,
      c.daily_step_target,
      c.ends_at,
      mcp.current_count,
      mcp.last_activity_date,
      mcp.completed_at
    from public.member_challenge_progress mcp
    join public.profiles p on p.id = mcp.profile_id
    join public.challenges c on c.id = mcp.challenge_id
    where c.is_active
      and mcp.completed_at is null
      and mcp.rewarded_at is null
      and not exists (
        select 1 from public.challenge_reminder_log crl
        where crl.profile_id = p.id and crl.reminder_date = v_today
      )
  loop
    v_title := null;
    v_body := null;
    v_remaining := greatest(v_row.target_count - v_row.current_count, 0);
    v_steps_today := 0;

    select coalesce(mds.step_count, 0)
    into v_steps_today
    from public.member_daily_steps mds
    where mds.profile_id = v_row.profile_id
      and mds.step_date = v_today;

    if p_pass = 'evening' then
      if v_row.challenge_type = 'login_streak'
        and v_row.current_count > 0
        and (v_row.last_activity_date is null or v_row.last_activity_date <> v_today)
      then
        v_title := public.get_app_setting_text('challenge_streak_at_risk_title', 'Keep your streak going');
        v_body := public.interpolate_template(
          public.get_app_setting_text('challenge_streak_at_risk_body', 'Your {streak}-day streak is waiting — one quick visit keeps it alive.'),
          v_row.first_name,
          null,
          jsonb_build_object('streak', v_row.current_count::text)
        );
      elsif v_row.challenge_type = 'step_streak'
        and v_row.current_count > 0
        and v_row.daily_step_target is not null
        and v_steps_today < v_row.daily_step_target
        and (v_row.last_activity_date is null or v_row.last_activity_date <> v_today)
      then
        v_title := public.get_app_setting_text('step_streak_at_risk_title', 'Don''t break your walk streak');
        v_body := public.interpolate_template(
          public.get_app_setting_text('step_streak_at_risk_body', 'Hit {daily_step_target} steps today to keep your streak alive and earn {reward_points} points.'),
          v_row.first_name,
          null,
          jsonb_build_object(
            'daily_step_target', v_row.daily_step_target::text,
            'reward_points', v_row.reward_points::text
          )
        );
      elsif v_row.challenge_type = 'step_streak'
        and v_row.daily_step_target is not null
        and v_steps_today > 0
        and v_steps_today < v_row.daily_step_target
      then
        v_steps_remaining := v_row.daily_step_target - v_steps_today;
        if v_steps_remaining <= v_near_threshold then
          v_title := public.get_app_setting_text('step_near_daily_goal_title', 'Almost at today''s goal');
          v_body := public.interpolate_template(
            public.get_app_setting_text('step_near_daily_goal_body', 'Just {steps_remaining} steps left today — you''ve got this!'),
            v_row.first_name,
            null,
            jsonb_build_object('steps_remaining', v_steps_remaining::text)
          );
        else
          v_title := public.get_app_setting_text('step_low_activity_title', 'Keep moving');
          v_body := public.interpolate_template(
            public.get_app_setting_text('step_low_activity_body', 'You''re at {steps_today} steps — {steps_remaining} to go for today''s goal. A short walk gets you closer to your reward!'),
            v_row.first_name,
            null,
            jsonb_build_object(
              'steps_today', v_steps_today::text,
              'steps_remaining', v_steps_remaining::text
            )
          );
        end if;
      elsif v_remaining = 1 then
        v_title := public.get_app_setting_text('challenge_near_completion_title', 'Almost there!');
        v_body := public.interpolate_template(
          public.get_app_setting_text('challenge_near_completion_body', 'One more step and you unlock {reward_points} points!'),
          v_row.first_name,
          null,
          jsonb_build_object('reward_points', v_row.reward_points::text)
        );
      end if;
    else
      if v_row.challenge_type = 'step_streak'
        and v_row.current_count > 0
        and not exists (
          select 1
          from public.member_daily_steps mds
          where mds.profile_id = v_row.profile_id
            and mds.step_date = v_today - 1
        )
      then
        v_title := public.get_app_setting_text('step_sync_reminder_title', 'Sync your steps');
        v_body := public.get_app_setting_text('step_sync_reminder_body', 'Open Groundup to sync yesterday''s steps and keep your walking challenge on track.');
      elsif v_row.last_activity_date is not null
        and v_row.last_activity_date <= v_today - v_inactive_days
        and v_row.current_count > 0
        and v_row.challenge_type not in ('step_streak', 'step_total')
      then
        v_title := public.get_app_setting_text('challenge_inactive_title', 'We miss you');
        v_body := public.interpolate_template(
          public.get_app_setting_text('challenge_inactive_body', 'You''re {remaining} steps from {reward_points} points. Pop in when you can.'),
          v_row.first_name,
          null,
          jsonb_build_object(
            'remaining', v_remaining::text,
            'reward_points', v_row.reward_points::text
          )
        );
      elsif v_row.challenge_type = 'login_streak'
        and v_row.last_activity_date = v_today - 1
        and v_row.current_count = 0
      then
        v_title := public.get_app_setting_text('challenge_streak_broken_title', 'Fresh start');
        v_body := public.get_app_setting_text('challenge_streak_broken_body', 'No worries — every streak starts with day one. Ready when you are.');
      elsif v_row.ends_at is not null
        and v_row.ends_at <= now() + interval '2 days'
        and v_row.ends_at > now()
      then
        v_title := public.get_app_setting_text('challenge_ending_soon_title', 'Time is running out');
        v_body := public.interpolate_template(
          public.get_app_setting_text('challenge_ending_soon_body', '{challenge_name} ends in 2 days — still time to finish!'),
          v_row.first_name,
          null,
          jsonb_build_object('challenge_name', v_row.challenge_name)
        );
      end if;
    end if;

    if v_title is null then
      continue;
    end if;

    perform public.create_notification(
      v_row.profile_id,
      'challenge',
      v_title,
      v_body,
      jsonb_build_object('route', '/customer/steps'),
      'challenge',
      v_row.challenge_id
    );

    insert into public.challenge_reminder_log (profile_id, reminder_date, reminder_type)
    values (v_row.profile_id, v_today, p_pass)
    on conflict (profile_id, reminder_date) do nothing;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;
-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant execute on function public.record_daily_steps(date, integer) to authenticated;
grant execute on function public.get_member_daily_steps(integer) to authenticated;
grant execute on function public.get_member_steps_today() to authenticated;
grant execute on function public.get_active_challenges_for_member(uuid) to authenticated;
grant execute on function public.get_notification_settings() to authenticated;
grant execute on function public.upsert_challenge_admin(
  uuid,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  integer,
  timestamptz,
  timestamptz,
  boolean,
  integer
) to authenticated;
