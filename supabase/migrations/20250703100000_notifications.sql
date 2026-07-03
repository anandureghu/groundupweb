-- Push notifications, in-app inbox, birthday rewards, challenge reminders, admin broadcasts

-- ---------------------------------------------------------------------------
-- Helpers: London timezone
-- ---------------------------------------------------------------------------

create or replace function public.get_london_now()
returns timestamptz
language sql
stable
as $$
  select now() at time zone 'Europe/London';
$$;
create or replace function public.get_london_date()
returns date
language sql
stable
as $$
  select (now() at time zone 'Europe/London')::date;
$$;
create or replace function public.get_london_year()
returns integer
language sql
stable
as $$
  select extract(year from now() at time zone 'Europe/London')::integer;
$$;
create or replace function public.is_profile_birthday_today(p_birthday date)
returns boolean
language sql
stable
as $$
  select
    p_birthday is not null
    and extract(month from p_birthday) = extract(month from public.get_london_now())
    and extract(day from p_birthday) = extract(day from public.get_london_now());
$$;
create or replace function public.interpolate_template(
  p_template text,
  p_first_name text default '',
  p_discount integer default null,
  p_extra jsonb default '{}'::jsonb
)
returns text
language plpgsql
immutable
as $$
declare
  v_result text := coalesce(p_template, '');
  v_key text;
  v_value text;
begin
  v_result := replace(v_result, '{first_name}', coalesce(nullif(trim(p_first_name), ''), 'there'));
  if p_discount is not null then
    v_result := replace(v_result, '{discount}', p_discount::text);
  end if;

  for v_key, v_value in select * from jsonb_each_text(coalesce(p_extra, '{}'::jsonb))
  loop
    v_result := replace(v_result, '{' || v_key || '}', v_value);
  end loop;

  return v_result;
end;
$$;
-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  expo_push_token text not null,
  platform text not null check (platform in ('ios', 'android', 'web', 'unknown')),
  device_id text,
  last_seen_at timestamptz not null default now(),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (expo_push_token)
);
create index push_tokens_profile_active_idx
  on public.push_tokens (profile_id, is_active);
create trigger push_tokens_set_updated_at
before update on public.push_tokens
for each row
execute function public.set_updated_at();
create table public.notification_preferences (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  order_updates boolean not null default true,
  challenge_reminders boolean not null default true,
  marketing boolean not null default false,
  birthday boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row
execute function public.set_updated_at();
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  type text not null check (type in ('order', 'birthday', 'challenge', 'coupon', 'admin', 'system')),
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  expires_at timestamptz,
  push_status text not null default 'pending'
    check (push_status in ('pending', 'sent', 'skipped', 'failed')),
  push_error text,
  source_type text,
  source_id uuid,
  created_at timestamptz not null default now()
);
create index notifications_profile_created_idx
  on public.notifications (profile_id, created_at desc);
create index notifications_profile_unread_idx
  on public.notifications (profile_id)
  where read_at is null;
create index notifications_push_pending_idx
  on public.notifications (created_at)
  where push_status = 'pending';
create table public.birthday_reward_log (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  reward_year integer not null,
  member_coupon_id uuid references public.member_coupons (id) on delete set null,
  notified_at timestamptz not null default now(),
  unique (profile_id, reward_year)
);
create table public.admin_broadcasts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  audience_type text not null check (audience_type in ('all', 'selected', 'segment')),
  audience_filter jsonb not null default '{}'::jsonb,
  selected_profile_ids uuid[] not null default '{}',
  scheduled_for timestamptz,
  sent_at timestamptz,
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'sending', 'sent', 'cancelled')),
  recipient_count integer not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger admin_broadcasts_set_updated_at
before update on public.admin_broadcasts
for each row
execute function public.set_updated_at();
create table public.notification_send_log (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications (id) on delete cascade,
  expo_push_token text,
  expo_ticket_id text,
  attempted_at timestamptz not null default now(),
  error text
);
create table public.challenge_reminder_log (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  reminder_date date not null,
  reminder_type text not null,
  created_at timestamptz not null default now(),
  unique (profile_id, reminder_date)
);
-- ---------------------------------------------------------------------------
-- Extend coupons + marketing banners
-- ---------------------------------------------------------------------------

alter table public.member_coupons
  add column if not exists source_type text
    check (source_type is null or source_type in ('admin', 'banner', 'birthday', 'system'));
alter table public.marketing_banners
  add column if not exists trigger_type text not null default 'always'
    check (trigger_type in ('always', 'birthday_only'));
-- ---------------------------------------------------------------------------
-- App settings seeds
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value_integer, value_text, description)
values
  ('birthday_coupon_enabled', 1, null, 'Enable automatic birthday coupon assignment'),
  ('birthday_coupon_discount_percent', 15, null, 'Birthday coupon discount percent'),
  ('birthday_coupon_validity_days', 14, null, 'Days until birthday coupon expires after assignment'),
  ('birthday_coupon_min_order_cents', 0, null, 'Minimum order for birthday coupon'),
  ('challenge_reminder_enabled', 1, null, 'Enable challenge reminder notifications'),
  ('challenge_streak_reminder_hour', 20, null, 'Hour (London) for streak-at-risk reminders'),
  ('challenge_inactive_days_threshold', 3, null, 'Days inactive before reminder'),
  ('order_notify_ready', 1, null, 'Notify when order is ready'),
  ('order_notify_cancelled', 1, null, 'Notify when order is cancelled'),
  ('order_notify_confirmed', 0, null, 'Notify when order is confirmed'),
  ('birthday_notification_title', 0, 'Happy Birthday, {first_name}!', 'Birthday push/in-app title'),
  ('birthday_notification_body', 0, 'We''ve added {discount}% off to your wallet — treat yourself today.', 'Birthday push/in-app body'),
  ('birthday_coupon_title', 0, 'Birthday treat', 'Birthday coupon wallet title'),
  ('birthday_coupon_description', 0, 'Your birthday gift from Ground Up', 'Birthday coupon wallet description'),
  ('challenge_streak_at_risk_title', 0, 'Keep your streak going', 'Challenge reminder title'),
  ('challenge_streak_at_risk_body', 0, 'Your {streak}-day streak is waiting — one quick visit keeps it alive.', 'Challenge reminder body'),
  ('challenge_near_completion_title', 0, 'Almost there!', 'Challenge reminder title'),
  ('challenge_near_completion_body', 0, 'One more step and you unlock {reward_points} points!', 'Challenge reminder body'),
  ('challenge_inactive_title', 0, 'We miss you', 'Challenge reminder title'),
  ('challenge_inactive_body', 0, 'You''re {remaining} steps from {reward_points} points. Pop in when you can.', 'Challenge reminder body'),
  ('challenge_streak_broken_title', 0, 'Fresh start', 'Challenge reminder title'),
  ('challenge_streak_broken_body', 0, 'No worries — every streak starts with day one. Ready when you are.', 'Challenge reminder body'),
  ('challenge_ending_soon_title', 0, 'Time is running out', 'Challenge reminder title'),
  ('challenge_ending_soon_body', 0, '{challenge_name} ends in 2 days — still time to finish!', 'Challenge reminder body')
on conflict (key) do nothing;
-- Seed birthday banner
insert into public.marketing_banners (
  slug,
  placement,
  trigger_type,
  title,
  subtitle,
  detail_title,
  detail_body,
  cta_label,
  cta_href,
  popup_delay_seconds,
  is_active,
  sort_order
)
values (
  'birthday',
  'home_popup',
  'birthday_only',
  'Happy Birthday!',
  'Your birthday treat is waiting in your wallet.',
  'Happy Birthday, {first_name}!',
  'We''ve added {discount}% off to celebrate — tap below to view your coupon.',
  'View my coupon',
  '/customer/coupons',
  0,
  true,
  0
)
on conflict (slug) do nothing;
-- ---------------------------------------------------------------------------
-- Profile preference bootstrap
-- ---------------------------------------------------------------------------

create or replace function public.ensure_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_preferences (profile_id, marketing)
  values (new.id, coalesce(new.marketing_opt_in, false))
  on conflict (profile_id) do nothing;
  return new;
end;
$$;
drop trigger if exists profiles_ensure_notification_preferences on public.profiles;
create trigger profiles_ensure_notification_preferences
after insert on public.profiles
for each row
execute function public.ensure_notification_preferences();
insert into public.notification_preferences (profile_id, marketing)
select p.id, coalesce(p.marketing_opt_in, false)
from public.profiles p
on conflict (profile_id) do nothing;
-- ---------------------------------------------------------------------------
-- Notification preferences helpers
-- ---------------------------------------------------------------------------

create or replace function public.should_send_notification(
  p_profile_id uuid,
  p_type text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_prefs public.notification_preferences;
begin
  select * into v_prefs
  from public.notification_preferences
  where profile_id = p_profile_id;

  if not found then
    return true;
  end if;

  case p_type
    when 'order' then return v_prefs.order_updates;
    when 'birthday' then return v_prefs.birthday;
    when 'challenge' then return v_prefs.challenge_reminders;
    when 'admin' then return v_prefs.marketing;
    else return true;
  end case;
end;
$$;
create or replace function public.create_notification(
  p_profile_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb,
  p_source_type text default null,
  p_source_id uuid default null,
  p_expires_at timestamptz default null,
  p_force boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_push_status text;
begin
  if p_type not in ('order', 'birthday', 'challenge', 'coupon', 'admin', 'system') then
    raise exception 'Invalid notification type: %', p_type;
  end if;

  if not p_force and not public.should_send_notification(p_profile_id, p_type) then
    return null;
  end if;

  v_push_status := 'pending';

  insert into public.notifications (
    profile_id,
    type,
    title,
    body,
    data,
    source_type,
    source_id,
    expires_at,
    push_status
  )
  values (
    p_profile_id,
    p_type,
    p_title,
    coalesce(p_body, ''),
    coalesce(p_data, '{}'::jsonb),
    p_source_type,
    p_source_id,
    p_expires_at,
    v_push_status
  )
  returning id into v_id;

  return v_id;
end;
$$;
-- ---------------------------------------------------------------------------
-- Push token RPCs
-- ---------------------------------------------------------------------------

create or replace function public.register_push_token(
  p_expo_push_token text,
  p_platform text default 'unknown',
  p_device_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  if nullif(trim(p_expo_push_token), '') is null then
    raise exception 'Push token is required';
  end if;

  insert into public.push_tokens (
    profile_id,
    expo_push_token,
    platform,
    device_id,
    last_seen_at,
    is_active
  )
  values (
    v_profile_id,
    trim(p_expo_push_token),
    coalesce(nullif(trim(p_platform), ''), 'unknown'),
    nullif(trim(p_device_id), ''),
    now(),
    true
  )
  on conflict (expo_push_token) do update
  set
    profile_id = excluded.profile_id,
    platform = excluded.platform,
    device_id = excluded.device_id,
    last_seen_at = now(),
    is_active = true,
    updated_at = now();
end;
$$;
create or replace function public.deactivate_push_token(p_expo_push_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.push_tokens
  set is_active = false, updated_at = now()
  where expo_push_token = trim(p_expo_push_token)
    and profile_id = auth.uid();
end;
$$;
-- ---------------------------------------------------------------------------
-- In-app notification RPCs
-- ---------------------------------------------------------------------------

create or replace function public.list_notifications(
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof public.notifications
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select n.*
  from public.notifications n
  where n.profile_id = v_profile_id
  order by n.created_at desc
  limit greatest(p_limit, 1)
  offset greatest(p_offset, 0);
end;
$$;
create or replace function public.get_unread_notification_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where profile_id = auth.uid()
    and read_at is null;
$$;
create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = now()
  where id = p_notification_id
    and profile_id = auth.uid()
    and read_at is null;
end;
$$;
create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = now()
  where profile_id = auth.uid()
    and read_at is null;
end;
$$;
create or replace function public.get_notification_preferences()
returns public.notification_preferences
language sql
stable
security definer
set search_path = public
as $$
  select np.*
  from public.notification_preferences np
  where np.profile_id = auth.uid();
$$;
create or replace function public.update_notification_preferences(
  p_order_updates boolean default null,
  p_challenge_reminders boolean default null,
  p_marketing boolean default null,
  p_birthday boolean default null
)
returns public.notification_preferences
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_prefs public.notification_preferences;
begin
  if v_profile_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.notification_preferences (profile_id)
  values (v_profile_id)
  on conflict (profile_id) do nothing;

  update public.notification_preferences
  set
    order_updates = coalesce(p_order_updates, order_updates),
    challenge_reminders = coalesce(p_challenge_reminders, challenge_reminders),
    marketing = coalesce(p_marketing, marketing),
    birthday = coalesce(p_birthday, birthday),
    updated_at = now()
  where profile_id = v_profile_id
  returning * into v_prefs;

  return v_prefs;
end;
$$;
-- ---------------------------------------------------------------------------
-- Notification settings (admin)
-- ---------------------------------------------------------------------------

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
  challenge_ending_soon_body text
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
    public.get_app_setting_text('challenge_ending_soon_body', '{challenge_name} ends in 2 days — still time to finish!');
$$;
create or replace function public.update_notification_setting(
  p_key text,
  p_value_integer integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  if p_key not in (
    'birthday_coupon_enabled',
    'birthday_coupon_discount_percent',
    'birthday_coupon_validity_days',
    'birthday_coupon_min_order_cents',
    'challenge_reminder_enabled',
    'challenge_streak_reminder_hour',
    'challenge_inactive_days_threshold',
    'order_notify_ready',
    'order_notify_cancelled',
    'order_notify_confirmed'
  ) then
    raise exception 'Unknown notification setting key: %', p_key;
  end if;

  if p_value_integer < 0 then
    raise exception 'Setting value must be non-negative';
  end if;

  update public.app_settings
  set value_integer = p_value_integer, updated_at = now()
  where key = p_key;

  if not found then
    raise exception 'App setting not found: %', p_key;
  end if;
end;
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
    'challenge_ending_soon_body'
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
-- System coupon assignment + birthday processing
-- ---------------------------------------------------------------------------

create or replace function public.sync_birthday_coupon_definition()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_discount integer;
  v_validity_days integer;
  v_min_order integer;
  v_title text;
  v_description text;
  v_id uuid;
begin
  v_discount := public.get_app_setting_integer('birthday_coupon_discount_percent', 15);
  v_validity_days := public.get_app_setting_integer('birthday_coupon_validity_days', 14);
  v_min_order := public.get_app_setting_integer('birthday_coupon_min_order_cents', 0);
  v_title := public.get_app_setting_text('birthday_coupon_title', 'Birthday treat');
  v_description := public.get_app_setting_text('birthday_coupon_description', 'Your birthday gift from Ground Up');

  select id into v_id
  from public.coupon_definitions
  where slug = 'birthday-gift';

  if found then
    update public.coupon_definitions
    set
      title = v_title,
      description = v_description,
      discount_type = 'percent',
      discount_percent = v_discount,
      discount_amount_cents = null,
      min_order_cents = nullif(v_min_order, 0),
      validity_days_after_assign = v_validity_days,
      is_active = true,
      updated_at = now()
    where id = v_id;
  else
    insert into public.coupon_definitions (
      slug,
      title,
      description,
      discount_type,
      discount_percent,
      min_order_cents,
      validity_days_after_assign,
      per_member_max_uses,
      terms_content,
      is_active
    )
    values (
      'birthday-gift',
      v_title,
      v_description,
      'percent',
      v_discount,
      nullif(v_min_order, 0),
      v_validity_days,
      1,
      '',
      true
    )
    returning id into v_id;
  end if;

  return v_id;
end;
$$;
create or replace function public.assign_system_coupon(
  p_profile_id uuid,
  p_coupon_slug text,
  p_source_type text default 'system'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_definition public.coupon_definitions;
  v_member_coupon_id uuid;
  v_expires_at timestamptz;
begin
  select * into v_definition
  from public.coupon_definitions
  where slug = p_coupon_slug;

  if not found then
    raise exception 'Coupon not found: %', p_coupon_slug;
  end if;

  if exists (
    select 1
    from public.member_coupons mc
    where mc.profile_id = p_profile_id
      and mc.coupon_definition_id = v_definition.id
      and mc.status = 'active'
  ) then
    select mc.id into v_member_coupon_id
    from public.member_coupons mc
    where mc.profile_id = p_profile_id
      and mc.coupon_definition_id = v_definition.id
      and mc.status = 'active'
    limit 1;
    return v_member_coupon_id;
  end if;

  v_expires_at := public.compute_member_coupon_expires_at(v_definition, now());

  insert into public.member_coupons (
    coupon_definition_id,
    profile_id,
    assigned_by,
    expires_at,
    status,
    source_type
  )
  values (
    v_definition.id,
    p_profile_id,
    null,
    v_expires_at,
    'active',
    p_source_type
  )
  returning id into v_member_coupon_id;

  return v_member_coupon_id;
end;
$$;
create or replace function public.process_birthday_rewards()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enabled integer;
  v_discount integer;
  v_title text;
  v_body text;
  v_coupon_id uuid;
  v_profile record;
  v_member_coupon_id uuid;
  v_count integer := 0;
  v_year integer := public.get_london_year();
begin
  v_enabled := public.get_app_setting_integer('birthday_coupon_enabled', 1);
  if v_enabled = 0 then
    return 0;
  end if;

  v_coupon_id := public.sync_birthday_coupon_definition();
  v_discount := public.get_app_setting_integer('birthday_coupon_discount_percent', 15);
  v_title := public.get_app_setting_text('birthday_notification_title', 'Happy Birthday, {first_name}!');
  v_body := public.get_app_setting_text('birthday_notification_body', 'We''ve added {discount}% off to your wallet — treat yourself today.');

  for v_profile in
    select p.id, p.first_name, p.birthday
    from public.profiles p
    where p.staff_role is null
      and public.is_profile_birthday_today(p.birthday)
      and not exists (
        select 1
        from public.birthday_reward_log brl
        where brl.profile_id = p.id
          and brl.reward_year = v_year
      )
  loop
    v_member_coupon_id := public.assign_system_coupon(v_profile.id, 'birthday-gift', 'birthday');

    insert into public.birthday_reward_log (profile_id, reward_year, member_coupon_id)
    values (v_profile.id, v_year, v_member_coupon_id)
    on conflict (profile_id, reward_year) do nothing;

    perform public.create_notification(
      v_profile.id,
      'birthday',
      public.interpolate_template(v_title, v_profile.first_name, v_discount),
      public.interpolate_template(v_body, v_profile.first_name, v_discount),
      jsonb_build_object('route', '/customer/coupons'),
      'birthday_reward',
      v_member_coupon_id
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;
-- ---------------------------------------------------------------------------
-- Birthday banner RPC
-- ---------------------------------------------------------------------------

create or replace function public.get_birthday_banner_for_member(p_profile_id uuid default null)
returns public.marketing_banners
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := coalesce(p_profile_id, auth.uid());
  v_profile public.profiles;
  v_banner public.marketing_banners;
  v_discount integer;
begin
  if v_profile_id is null then
    return null;
  end if;

  if public.get_app_setting_integer('birthday_coupon_enabled', 1) = 0 then
    return null;
  end if;

  select * into v_profile
  from public.profiles
  where id = v_profile_id;

  if not found or not public.is_profile_birthday_today(v_profile.birthday) then
    return null;
  end if;

  select * into v_banner
  from public.marketing_banners b
  where b.slug = 'birthday'
    and b.trigger_type = 'birthday_only'
    and b.is_active
    and public.is_marketing_banner_active(b)
  limit 1;

  if not found then
    return null;
  end if;

  v_discount := public.get_app_setting_integer('birthday_coupon_discount_percent', 15);

  v_banner.detail_title := public.interpolate_template(v_banner.detail_title, v_profile.first_name, v_discount);
  v_banner.detail_body := public.interpolate_template(v_banner.detail_body, v_profile.first_name, v_discount);
  v_banner.title := public.interpolate_template(v_banner.title, v_profile.first_name, v_discount);
  v_banner.subtitle := public.interpolate_template(v_banner.subtitle, v_profile.first_name, v_discount);

  return v_banner;
end;
$$;
-- Update marketing banner queries to exclude birthday_only
create or replace function public.get_active_marketing_banners(p_placement text)
returns setof public.marketing_banners
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_placement not in ('home_slider', 'home_popup') then
    raise exception 'Invalid banner placement: %', p_placement;
  end if;

  return query
  select *
  from public.marketing_banners b
  where b.placement = p_placement
    and b.trigger_type = 'always'
    and public.is_marketing_banner_active(b)
  order by b.sort_order, b.created_at;
end;
$$;
-- ---------------------------------------------------------------------------
-- Order status notifications
-- ---------------------------------------------------------------------------

create or replace function public.notify_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
  v_store_name text;
begin
  if tg_op <> 'UPDATE' or new.status is not distinct from old.status then
    return new;
  end if;

  select s.name into v_store_name
  from public.stores s
  where s.id = new.store_id;

  case new.status
    when 'ready' then
      if public.get_app_setting_integer('order_notify_ready', 1) = 0 then
        return new;
      end if;
      v_title := 'Order ready';
      v_body := format('Order #%s is ready for pickup!', new.order_number);
    when 'cancelled' then
      if public.get_app_setting_integer('order_notify_cancelled', 1) = 0 then
        return new;
      end if;
      v_title := 'Order cancelled';
      v_body := format('Order #%s was cancelled.', new.order_number);
    when 'confirmed' then
      if public.get_app_setting_integer('order_notify_confirmed', 0) = 0 then
        return new;
      end if;
      v_title := 'Order confirmed';
      v_body := format('Order #%s confirmed — we''re on it.', new.order_number);
    else
      return new;
  end case;

  perform public.create_notification(
    new.profile_id,
    'order',
    v_title,
    v_body,
    jsonb_build_object('route', '/customer/orders/' || new.id::text, 'orderId', new.id::text),
    'order',
    new.id
  );

  return new;
end;
$$;
drop trigger if exists orders_notify_status_change on public.orders;
create trigger orders_notify_status_change
after update of status on public.orders
for each row
execute function public.notify_order_status_change();
-- ---------------------------------------------------------------------------
-- Challenge reminders
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
      if v_row.last_activity_date is not null
        and v_row.last_activity_date <= v_today - v_inactive_days
        and v_row.current_count > 0
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
      jsonb_build_object('route', '/customer/challenges'),
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
-- Admin broadcasts
-- ---------------------------------------------------------------------------

create or replace function public.resolve_broadcast_audience(
  p_audience_type text,
  p_audience_filter jsonb default '{}'::jsonb,
  p_selected_profile_ids uuid[] default '{}'
)
returns setof uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_audience_type = 'selected' then
    return query
    select unnest(p_selected_profile_ids);
    return;
  end if;

  if p_audience_type = 'all' then
    return query
    select p.id
    from public.profiles p
    where p.staff_role is null;
    return;
  end if;

  if p_audience_type = 'segment' then
    case coalesce(p_audience_filter->>'segment', '')
      when 'inactive_7d' then
        return query
        select p.id
        from public.profiles p
        where p.staff_role is null
          and not exists (
            select 1
            from public.member_challenge_progress mcp
            where mcp.profile_id = p.id
              and mcp.last_activity_date >= public.get_london_date() - 7
          );
      when 'birthday_this_week' then
        return query
        select p.id
        from public.profiles p
        where p.staff_role is null
          and p.birthday is not null
          and (
            (extract(doy from p.birthday) between extract(doy from public.get_london_date())
              and extract(doy from public.get_london_date() + 7))
          );
      when 'has_unused_coupon' then
        return query
        select distinct mc.profile_id
        from public.member_coupons mc
        where mc.status = 'active'
          and (mc.expires_at is null or mc.expires_at > now());
      else
        return;
    end case;
    return;
  end if;
end;
$$;
create or replace function public.preview_admin_broadcast_audience(
  p_audience_type text,
  p_audience_filter jsonb default '{}'::jsonb,
  p_selected_profile_ids uuid[] default '{}'
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.resolve_broadcast_audience(p_audience_type, p_audience_filter, p_selected_profile_ids) audience(id);
$$;
create or replace function public.create_admin_broadcast(
  p_title text,
  p_body text,
  p_audience_type text,
  p_audience_filter jsonb default '{}'::jsonb,
  p_selected_profile_ids uuid[] default '{}',
  p_scheduled_for timestamptz default null,
  p_data jsonb default '{}'::jsonb,
  p_send_now boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_count integer;
  v_status text;
begin
  perform public.assert_admin_access();

  if nullif(trim(p_title), '') is null or nullif(trim(p_body), '') is null then
    raise exception 'Title and body are required';
  end if;

  v_count := public.preview_admin_broadcast_audience(
    p_audience_type,
    p_audience_filter,
    p_selected_profile_ids
  );

  if p_send_now then
    v_status := 'sending';
  elsif p_scheduled_for is not null then
    v_status := 'scheduled';
  else
    v_status := 'draft';
  end if;

  insert into public.admin_broadcasts (
    title,
    body,
    data,
    audience_type,
    audience_filter,
    selected_profile_ids,
    scheduled_for,
    status,
    recipient_count,
    created_by
  )
  values (
    trim(p_title),
    trim(p_body),
    coalesce(p_data, '{}'::jsonb),
    p_audience_type,
    coalesce(p_audience_filter, '{}'::jsonb),
    coalesce(p_selected_profile_ids, '{}'),
    p_scheduled_for,
    v_status,
    v_count,
    auth.uid()
  )
  returning id into v_id;

  if p_send_now then
    perform public.process_admin_broadcast(v_id);
  end if;

  return v_id;
end;
$$;
create or replace function public.process_admin_broadcast(p_broadcast_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_broadcast public.admin_broadcasts;
  v_profile_id uuid;
  v_count integer := 0;
begin
  select * into v_broadcast
  from public.admin_broadcasts
  where id = p_broadcast_id
    and status in ('scheduled', 'sending', 'draft');

  if not found then
    return 0;
  end if;

  update public.admin_broadcasts
  set status = 'sending', updated_at = now()
  where id = p_broadcast_id;

  for v_profile_id in
    select audience.id
    from public.resolve_broadcast_audience(
      v_broadcast.audience_type,
      v_broadcast.audience_filter,
      v_broadcast.selected_profile_ids
    ) audience(id)
  loop
    perform public.create_notification(
      v_profile_id,
      'admin',
      v_broadcast.title,
      v_broadcast.body,
      coalesce(v_broadcast.data, '{}'::jsonb),
      'admin_broadcast',
      p_broadcast_id
    );
    v_count := v_count + 1;
  end loop;

  update public.admin_broadcasts
  set
    status = 'sent',
    sent_at = now(),
    recipient_count = v_count,
    updated_at = now()
  where id = p_broadcast_id;

  return v_count;
end;
$$;
create or replace function public.process_due_admin_broadcasts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_broadcast record;
  v_total integer := 0;
begin
  for v_broadcast in
    select id
    from public.admin_broadcasts
    where status = 'scheduled'
      and scheduled_for is not null
      and scheduled_for <= now()
  loop
    v_total := v_total + public.process_admin_broadcast(v_broadcast.id);
  end loop;

  return v_total;
end;
$$;
create or replace function public.cancel_admin_broadcast(p_broadcast_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  update public.admin_broadcasts
  set status = 'cancelled', updated_at = now()
  where id = p_broadcast_id
    and status in ('draft', 'scheduled');
end;
$$;
create or replace function public.list_admin_broadcasts()
returns setof public.admin_broadcasts
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select *
  from public.admin_broadcasts
  order by created_at desc;
end;
$$;
-- Push delivery helpers (called from edge function via service role)
create or replace function public.get_pending_notification(p_notification_id uuid)
returns table (
  notification_id uuid,
  profile_id uuid,
  type text,
  title text,
  body text,
  data jsonb,
  push_status text,
  order_updates boolean,
  challenge_reminders boolean,
  marketing boolean,
  birthday boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    n.id,
    n.profile_id,
    n.type,
    n.title,
    n.body,
    n.data,
    n.push_status,
    coalesce(np.order_updates, true),
    coalesce(np.challenge_reminders, true),
    coalesce(np.marketing, false),
    coalesce(np.birthday, true)
  from public.notifications n
  left join public.notification_preferences np on np.profile_id = n.profile_id
  where n.id = p_notification_id;
$$;
create or replace function public.get_active_push_tokens(p_profile_id uuid)
returns table (expo_push_token text)
language sql
stable
security definer
set search_path = public
as $$
  select pt.expo_push_token
  from public.push_tokens pt
  where pt.profile_id = p_profile_id
    and pt.is_active = true;
$$;
create or replace function public.mark_notification_push_result(
  p_notification_id uuid,
  p_status text,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set push_status = p_status, push_error = p_error
  where id = p_notification_id;
end;
$$;
create or replace function public.deactivate_push_tokens_by_value(p_tokens text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.push_tokens
  set is_active = false, updated_at = now()
  where expo_push_token = any(p_tokens);
end;
$$;
-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.push_tokens enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.birthday_reward_log enable row level security;
alter table public.admin_broadcasts enable row level security;
alter table public.notification_send_log enable row level security;
alter table public.challenge_reminder_log enable row level security;
create policy push_tokens_select_own on public.push_tokens
  for select using (profile_id = auth.uid());
create policy push_tokens_insert_own on public.push_tokens
  for insert with check (profile_id = auth.uid());
create policy push_tokens_update_own on public.push_tokens
  for update using (profile_id = auth.uid());
create policy notification_preferences_select_own on public.notification_preferences
  for select using (profile_id = auth.uid());
create policy notification_preferences_update_own on public.notification_preferences
  for update using (profile_id = auth.uid());
create policy notifications_select_own on public.notifications
  for select using (profile_id = auth.uid());
create policy notifications_update_own on public.notifications
  for update using (profile_id = auth.uid());
-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.notifications;
-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.deactivate_push_token(text) to authenticated;
grant execute on function public.list_notifications(integer, integer) to authenticated;
grant execute on function public.get_unread_notification_count() to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
grant execute on function public.get_notification_preferences() to authenticated;
grant execute on function public.update_notification_preferences(boolean, boolean, boolean, boolean) to authenticated;
grant execute on function public.get_birthday_banner_for_member(uuid) to authenticated;
grant execute on function public.get_notification_settings() to authenticated;
grant execute on function public.update_notification_setting(text, integer) to authenticated;
grant execute on function public.update_notification_setting_text(text, text) to authenticated;
grant execute on function public.preview_admin_broadcast_audience(text, jsonb, uuid[]) to authenticated;
grant execute on function public.create_admin_broadcast(text, text, text, jsonb, uuid[], timestamptz, jsonb, boolean) to authenticated;
grant execute on function public.cancel_admin_broadcast(uuid) to authenticated;
grant execute on function public.list_admin_broadcasts() to authenticated;
grant execute on function public.sync_birthday_coupon_definition() to service_role;
grant execute on function public.process_birthday_rewards() to service_role;
grant execute on function public.assign_system_coupon(uuid, text, text) to service_role;
grant execute on function public.process_challenge_reminders(text) to service_role;
grant execute on function public.process_due_admin_broadcasts() to service_role;
grant execute on function public.process_admin_broadcast(uuid) to service_role;
grant execute on function public.get_pending_notification(uuid) to service_role;
grant execute on function public.get_active_push_tokens(uuid) to service_role;
grant execute on function public.mark_notification_push_result(uuid, text, text) to service_role;
grant execute on function public.deactivate_push_tokens_by_value(text[]) to service_role;
-- Cron / webhook setup (manual in Supabase Dashboard):
-- 1. Database Webhook: notifications INSERT where push_status=pending -> send-notification
-- 2. Schedule birthday-coupon-job: 5 0 * * * (Europe/London)
-- 3. Schedule challenge-reminder-job morning: 0 10 * * * (Europe/London) body {"pass":"morning"}
-- 4. Schedule challenge-reminder-job evening: 0 20 * * * (Europe/London) body {"pass":"evening"}
-- 5. Schedule process-admin-broadcasts: * * * * *;
