-- Referral rewards: joiner 100 pts; referrer 1000 at every multiple of 5.
-- One-time ledger correction + member notice.
-- app_copy bank + version gate settings + admin helpers.

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

insert into public.app_settings (key, value_integer, value_text, description)
values
  (
    'referral_joiner_points',
    100,
    null,
    'Points awarded to a new member who joins with a valid referral code'
  ),
  (
    'min_supported_app_version',
    0,
    '',
    'Minimum app version (semver) allowed to use the app. Empty = no gate.'
  ),
  (
    'new_version_available',
    0,
    null,
    '1 when a store build meeting min_supported_app_version is available'
  )
on conflict (key) do nothing;

update public.app_settings
set
  value_integer = 1000,
  description = 'Points awarded to the referrer each time successful referrals hit a multiple of referral_target_count',
  updated_at = now()
where key = 'referral_milestone_bonus_points';

update public.app_settings
set
  description = 'Successful referral interval for referrer milestone rewards (every N referrals)',
  updated_at = now()
where key = 'referral_target_count';

update public.app_settings
set
  description = 'Deprecated: use referral_joiner_points. Kept for history.',
  updated_at = now()
where key = 'referral_points_per_party';

update public.app_settings
set
  value_text = 'Welcome to the Society, {first_name}!',
  updated_at = now()
where key = 'referral_referee_welcome_title';

update public.app_settings
set
  value_text = 'You earned {points} points for joining with a friend''s invite.',
  updated_at = now()
where key = 'referral_referee_welcome_body';

update public.app_settings
set
  value_text = 'Nice one, {first_name}!',
  updated_at = now()
where key = 'referral_referrer_success_title';

update public.app_settings
set
  value_text = 'A new member joined with your code. You''re at {count} successful referrals — every {target} unlocks {bonus} points.',
  updated_at = now()
where key = 'referral_referrer_success_body';

update public.app_settings
set
  value_text = 'Referral milestone!',
  updated_at = now()
where key = 'referral_milestone_title';

update public.app_settings
set
  value_text = 'You reached {count} referrals. {bonus} points are yours.',
  updated_at = now()
where key = 'referral_milestone_body';

update public.app_settings
set
  value_text = 'Referral progress: {count}/{target}',
  updated_at = now()
where key = 'referral_progress_nudge_title';

update public.app_settings
set
  value_text = 'Keep sharing — {count} of {target} toward your next {bonus}-point milestone.',
  updated_at = now()
where key = 'referral_progress_nudge_body';

-- ---------------------------------------------------------------------------
-- app_copy
-- ---------------------------------------------------------------------------

create table if not exists public.app_copy (
  key text primary key,
  title text not null default '',
  body text not null default '',
  description text,
  updated_at timestamptz not null default now()
);

alter table public.app_copy enable row level security;

drop policy if exists app_copy_select_authenticated on public.app_copy;
create policy app_copy_select_authenticated
  on public.app_copy
  for select
  to authenticated
  using (true);

insert into public.app_copy (key, title, body, description)
values
  (
    'referral_correction_notice',
    'A quick update on your points',
    'We made a mistake on referral rewards and have corrected your balance. Going forward, friends who join with your code get a small welcome bonus, and you earn a larger reward every five successful referrals. Thanks for your patience.',
    'Shown once to members whose referral points were corrected'
  ),
  (
    'version_update_required',
    'Update required',
    'A new version of Groundup Society is available. Please update the app to continue.',
    'Blocking screen when below min version and new_version_available = 1'
  ),
  (
    'version_update_pending',
    'We''re making changes',
    'Groundup Society is updating. You''ll be able to use the app again once the new version is available. Thanks for waiting.',
    'Blocking screen when below min version and new_version_available = 0'
  )
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Member notices
-- ---------------------------------------------------------------------------

create table if not exists public.member_notices (
  id uuid primary key default gen_random_uuid(),
  copy_key text not null references public.app_copy (key) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.member_notice_recipients (
  notice_id uuid not null references public.member_notices (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  seen_at timestamptz,
  primary key (notice_id, user_id)
);

create index if not exists member_notice_recipients_user_unseen_idx
  on public.member_notice_recipients (user_id)
  where seen_at is null;

alter table public.member_notices enable row level security;
alter table public.member_notice_recipients enable row level security;

-- Access via security definer RPCs only
drop policy if exists member_notices_deny_all on public.member_notices;
create policy member_notices_deny_all
  on public.member_notices
  for all
  to authenticated
  using (false)
  with check (false);

drop policy if exists member_notice_recipients_deny_all on public.member_notice_recipients;
create policy member_notice_recipients_deny_all
  on public.member_notice_recipients
  for all
  to authenticated
  using (false)
  with check (false);

-- ---------------------------------------------------------------------------
-- Reward settings RPC
-- ---------------------------------------------------------------------------

drop function if exists public.get_reward_settings();

create function public.get_reward_settings()
returns table (
  purchase_points_per_product integer,
  referral_points_per_party integer,
  referral_joiner_points integer,
  default_points_to_redeem integer,
  default_redeem_title text,
  default_redeem_description text,
  active_app_banner_template text,
  referral_target_count integer,
  referral_milestone_bonus_points integer
)
language sql
stable
as $$
  select
    public.get_app_setting_integer('purchase_points_per_product', 50),
    public.get_app_setting_integer(
      'referral_joiner_points',
      public.get_app_setting_integer('referral_points_per_party', 100)
    ),
    public.get_app_setting_integer(
      'referral_joiner_points',
      public.get_app_setting_integer('referral_points_per_party', 100)
    ),
    public.get_app_setting_integer('default_points_to_redeem', 200),
    public.get_app_setting_text('default_redeem_title', 'Claim with points'),
    public.get_app_setting_text(
      'default_redeem_description',
      'Visit the counter and show your member QR to redeem this item.'
    ),
    coalesce(
      (
        select trim(value_text)
        from public.app_settings
        where key = 'active_app_banner_template'
      ),
      ''
    ),
    public.get_app_setting_integer('referral_target_count', 5),
    public.get_app_setting_integer('referral_milestone_bonus_points', 1000);
$$;

grant execute on function public.get_reward_settings()
  to anon, authenticated, service_role;

create or replace function public.update_app_setting(
  p_key text,
  p_value_integer integer
)
returns void
language plpgsql
as $$
begin
  perform public.assert_admin_access();

  if p_key not in (
    'purchase_points_per_product',
    'referral_points_per_party',
    'referral_joiner_points',
    'default_points_to_redeem',
    'referral_target_count',
    'referral_milestone_bonus_points',
    'new_version_available'
  ) then
    raise exception 'Unknown app setting key: %', p_key;
  end if;

  if p_value_integer < 0 then
    raise exception 'Setting value must be non-negative';
  end if;

  if p_key = 'referral_target_count' and p_value_integer < 1 then
    raise exception 'Referral target count must be at least 1';
  end if;

  if p_key = 'new_version_available' and p_value_integer not in (0, 1) then
    raise exception 'new_version_available must be 0 or 1';
  end if;

  update public.app_settings
  set
    value_integer = p_value_integer,
    updated_at = now()
  where key = p_key;

  if not found then
    raise exception 'App setting not found: %', p_key;
  end if;
end;
$$;

create or replace function public.update_app_setting_text(
  p_key text,
  p_value_text text
)
returns void
language plpgsql
as $$
declare
  v_trimmed text := trim(coalesce(p_value_text, ''));
begin
  perform public.assert_admin_access();

  if p_key not in (
    'default_redeem_title',
    'default_redeem_description',
    'legal_documents_version',
    'terms_content',
    'privacy_policy_content',
    'active_app_banner_template',
    'min_supported_app_version'
  ) then
    raise exception 'Unknown app setting key: %', p_key;
  end if;

  if p_key = 'active_app_banner_template' then
    if v_trimmed <> '' and v_trimmed not in ('referral') then
      raise exception 'Unknown app banner template: %', v_trimmed;
    end if;
  elsif p_key = 'min_supported_app_version' then
    -- empty allowed (gate off)
    null;
  elsif v_trimmed = '' then
    raise exception 'Setting value must not be empty';
  end if;

  update public.app_settings
  set
    value_text = v_trimmed,
    updated_at = now()
  where key = p_key;

  if not found then
    raise exception 'App setting not found: %', p_key;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- apply_referral_on_signup (new rules)
-- ---------------------------------------------------------------------------

create or replace function public.apply_referral_on_signup(
  p_referee_id uuid,
  p_referral_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer_id uuid;
  v_joiner_points integer;
  v_referee_metadata jsonb;
  v_normalized_code text;
  v_successful_count integer;
  v_target_count integer;
  v_milestone_bonus integer;
  v_notifications_enabled integer;
  v_referee_name text;
  v_referrer_name text;
  v_extra jsonb;
  v_title text;
  v_body text;
  v_hit_milestone boolean := false;
  v_cycle_count integer;
begin
  v_normalized_code := upper(trim(p_referral_code));

  if v_normalized_code = '' then
    return;
  end if;

  select id
  into v_referrer_id
  from public.profiles
  where referral_code = v_normalized_code;

  if not found then
    raise exception 'Invalid referral code';
  end if;

  if v_referrer_id = p_referee_id then
    raise exception 'Cannot use your own referral code';
  end if;

  if exists (
    select 1
    from public.profiles
    where id = p_referee_id
      and referred_by_id is not null
  ) then
    raise exception 'Referral reward already applied for this member';
  end if;

  if exists (
    select 1
    from public.reward_transactions
    where profile_id = p_referee_id
      and type = 'referral'
  ) then
    raise exception 'Referral reward already applied for this member';
  end if;

  v_joiner_points := public.get_app_setting_integer(
    'referral_joiner_points',
    public.get_app_setting_integer('referral_points_per_party', 100)
  );

  update public.profiles
  set
    referred_by_id = v_referrer_id,
    updated_at = now()
  where id = p_referee_id
    and referred_by_id is null;

  if not found then
    raise exception 'Referral reward already applied for this member';
  end if;

  v_referee_metadata := jsonb_build_object(
    'rule', 'referral',
    'referral_joiner_points', v_joiner_points,
    'counterparty_profile_id', v_referrer_id,
    'role', 'referee'
  );

  if v_joiner_points > 0 then
    perform public.apply_reward_transaction(
      p_referee_id,
      v_joiner_points,
      'referral',
      'Referral signup bonus',
      null,
      v_referee_metadata
    );
  end if;

  select count(*)::integer
  into v_successful_count
  from public.profiles
  where referred_by_id = v_referrer_id;

  v_target_count := public.get_app_setting_integer('referral_target_count', 5);
  if v_target_count < 1 then
    v_target_count := 5;
  end if;

  v_milestone_bonus := public.get_app_setting_integer('referral_milestone_bonus_points', 1000);

  v_hit_milestone :=
    v_milestone_bonus > 0
    and v_successful_count > 0
    and (v_successful_count % v_target_count) = 0;

  if v_hit_milestone
    and not exists (
      select 1
      from public.reward_transactions
      where profile_id = v_referrer_id
        and type = 'referral'
        and coalesce(metadata->>'rule', '') = 'referral_milestone'
        and coalesce(metadata->>'at_count', '') = v_successful_count::text
    )
  then
    perform public.apply_reward_transaction(
      v_referrer_id,
      v_milestone_bonus,
      'referral',
      'Referral program milestone bonus',
      null,
      jsonb_build_object(
        'rule', 'referral_milestone',
        'referral_target_count', v_target_count,
        'at_count', v_successful_count,
        'successful_count', v_successful_count,
        'role', 'referrer'
      )
    );
  end if;

  v_cycle_count := v_successful_count % v_target_count;
  if v_cycle_count = 0 then
    v_cycle_count := v_target_count;
  end if;

  v_notifications_enabled := public.get_app_setting_integer('referral_notifications_enabled', 1);
  if v_notifications_enabled = 0 then
    return;
  end if;

  select first_name into v_referee_name from public.profiles where id = p_referee_id;
  select first_name into v_referrer_name from public.profiles where id = v_referrer_id;

  v_extra := jsonb_build_object(
    'points', v_joiner_points::text,
    'count', v_successful_count::text,
    'target', v_target_count::text,
    'bonus', v_milestone_bonus::text
  );

  v_title := public.interpolate_template(
    public.get_app_setting_text('referral_referee_welcome_title', 'Welcome to the Society, {first_name}!'),
    v_referee_name,
    null,
    v_extra
  );
  v_body := public.interpolate_template(
    public.get_app_setting_text('referral_referee_welcome_body', 'You earned {points} points for joining with a friend''s invite.'),
    v_referee_name,
    null,
    v_extra
  );
  perform public.create_notification(
    p_referee_id,
    'referral',
    v_title,
    v_body,
    jsonb_build_object('route', '/customer/rewards'),
    'referral',
    null
  );

  v_title := public.interpolate_template(
    public.get_app_setting_text('referral_referrer_success_title', 'Nice one, {first_name}!'),
    v_referrer_name,
    null,
    v_extra
  );
  v_body := public.interpolate_template(
    public.get_app_setting_text(
      'referral_referrer_success_body',
      'A new member joined with your code. You''re at {count} successful referrals — every {target} unlocks {bonus} points.'
    ),
    v_referrer_name,
    null,
    v_extra
  );
  perform public.create_notification(
    v_referrer_id,
    'referral',
    v_title,
    v_body,
    jsonb_build_object('route', '/customer/rewards'),
    'referral',
    null
  );

  if v_hit_milestone then
    v_title := public.interpolate_template(
      public.get_app_setting_text('referral_milestone_title', 'Referral milestone!'),
      v_referrer_name,
      null,
      v_extra
    );
    v_body := public.interpolate_template(
      public.get_app_setting_text(
        'referral_milestone_body',
        'You reached {count} referrals. {bonus} points are yours.'
      ),
      v_referrer_name,
      null,
      v_extra
    );
    perform public.create_notification(
      v_referrer_id,
      'referral',
      v_title,
      v_body,
      jsonb_build_object('route', '/customer/rewards'),
      'referral_milestone',
      null
    );
  else
    v_extra := v_extra || jsonb_build_object('count', v_cycle_count::text);
    v_title := public.interpolate_template(
      public.get_app_setting_text('referral_progress_nudge_title', 'Referral progress: {count}/{target}'),
      v_referrer_name,
      null,
      v_extra
    );
    v_body := public.interpolate_template(
      public.get_app_setting_text(
        'referral_progress_nudge_body',
        'Keep sharing — {count} of {target} toward your next {bonus}-point milestone.'
      ),
      v_referrer_name,
      null,
      v_extra
    );
    perform public.create_notification(
      v_referrer_id,
      'referral',
      v_title,
      v_body,
      jsonb_build_object('route', '/customer/rewards'),
      'referral_progress',
      null
    );
  end if;
end;
$$;

grant execute on function public.apply_referral_on_signup(uuid, text)
  to anon, authenticated, service_role;

create or replace function public.get_my_referral_progress()
returns table (
  successful_count integer,
  target_count integer,
  points_per_referral integer,
  milestone_bonus integer,
  milestone_claimed boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
  v_target integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select count(*)::integer
  into v_count
  from public.profiles
  where referred_by_id = v_uid;

  v_target := public.get_app_setting_integer('referral_target_count', 5);
  if v_target < 1 then
    v_target := 5;
  end if;

  return query
  select
    v_count as successful_count,
    v_target as target_count,
    public.get_app_setting_integer(
      'referral_joiner_points',
      public.get_app_setting_integer('referral_points_per_party', 100)
    ) as points_per_referral,
    public.get_app_setting_integer('referral_milestone_bonus_points', 1000) as milestone_bonus,
    (
      v_count > 0
      and (v_count % v_target) = 0
      and exists (
        select 1
        from public.reward_transactions
        where profile_id = v_uid
          and type = 'referral'
          and coalesce(metadata->>'rule', '') = 'referral_milestone'
          and coalesce(metadata->>'at_count', '') = v_count::text
      )
    ) as milestone_claimed;
end;
$$;

grant execute on function public.get_my_referral_progress()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- One-time referral points correction + notice recipients
-- ---------------------------------------------------------------------------

do $$
declare
  v_notice_id uuid;
  v_profile record;
  v_joiner_points integer := public.get_app_setting_integer('referral_joiner_points', 100);
  v_target integer := public.get_app_setting_integer('referral_target_count', 5);
  v_milestone integer := public.get_app_setting_integer('referral_milestone_bonus_points', 1000);
  v_credited integer;
  v_expected integer;
  v_delta integer;
  v_balance integer;
  v_apply integer;
  v_referred_count integer;
  v_affected integer := 0;
begin
  if v_target < 1 then
    v_target := 5;
  end if;

  insert into public.member_notices (copy_key, active)
  values ('referral_correction_notice', true)
  returning id into v_notice_id;

  for v_profile in
    select p.id, p.referred_by_id, p.points_balance
    from public.profiles p
    where p.referred_by_id is not null
       or exists (
         select 1 from public.profiles c where c.referred_by_id = p.id
       )
       or exists (
         select 1
         from public.reward_transactions rt
         where rt.profile_id = p.id
           and rt.type = 'referral'
       )
  loop
    select coalesce(sum(rt.points), 0)::integer
    into v_credited
    from public.reward_transactions rt
    where rt.profile_id = v_profile.id
      and rt.type = 'referral'
      and rt.points > 0;

    select count(*)::integer
    into v_referred_count
    from public.profiles
    where referred_by_id = v_profile.id;

    v_expected := 0;
    if v_profile.referred_by_id is not null then
      v_expected := v_expected + v_joiner_points;
    end if;
    v_expected := v_expected + (v_referred_count / v_target) * v_milestone;

    v_delta := v_expected - v_credited;
    if v_delta = 0 then
      continue;
    end if;

    v_balance := v_profile.points_balance;
    v_apply := v_delta;
    if v_apply < 0 and (v_balance + v_apply) < 0 then
      v_apply := -v_balance;
    end if;

    if v_apply = 0 then
      continue;
    end if;

    perform public.apply_reward_transaction(
      v_profile.id,
      v_apply,
      'adjustment',
      'Referral points correction',
      null,
      jsonb_build_object(
        'rule', 'referral_correction',
        'expected', v_expected,
        'previously_credited', v_credited,
        'requested_delta', v_delta,
        'applied_delta', v_apply
      )
    );

    insert into public.member_notice_recipients (notice_id, user_id)
    values (v_notice_id, v_profile.id)
    on conflict do nothing;

    v_affected := v_affected + 1;
  end loop;

  raise notice 'Referral correction applied to % profiles', v_affected;
end;
$$;

-- ---------------------------------------------------------------------------
-- Member notice RPCs
-- ---------------------------------------------------------------------------

create or replace function public.get_my_pending_member_notice()
returns table (
  notice_id uuid,
  copy_key text,
  title text,
  body text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    n.id,
    n.copy_key,
    c.title,
    c.body
  from public.member_notice_recipients r
  join public.member_notices n on n.id = r.notice_id
  join public.app_copy c on c.key = n.copy_key
  where r.user_id = v_uid
    and r.seen_at is null
    and n.active = true
  order by n.created_at asc
  limit 1;
end;
$$;

grant execute on function public.get_my_pending_member_notice()
  to authenticated, service_role;

create or replace function public.dismiss_member_notice(p_notice_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  update public.member_notice_recipients
  set seen_at = now()
  where notice_id = p_notice_id
    and user_id = v_uid
    and seen_at is null;
end;
$$;

grant execute on function public.dismiss_member_notice(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Version gate + app_copy helpers
-- ---------------------------------------------------------------------------

create or replace function public.get_app_version_gate()
returns table (
  min_supported_app_version text,
  new_version_available boolean,
  update_required_title text,
  update_required_body text,
  update_pending_title text,
  update_pending_body text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(
      (
        select trim(value_text)
        from public.app_settings
        where key = 'min_supported_app_version'
      ),
      ''
    ),
    public.get_app_setting_integer('new_version_available', 0) = 1,
    coalesce(
      (select title from public.app_copy where key = 'version_update_required'),
      'Update required'
    ),
    coalesce(
      (select body from public.app_copy where key = 'version_update_required'),
      'Please update the app to continue.'
    ),
    coalesce(
      (select title from public.app_copy where key = 'version_update_pending'),
      'We''re making changes'
    ),
    coalesce(
      (select body from public.app_copy where key = 'version_update_pending'),
      'You''ll be able to use the app again once the new version is available.'
    );
$$;

grant execute on function public.get_app_version_gate()
  to anon, authenticated, service_role;

create or replace function public.get_app_copy(p_key text)
returns table (
  key text,
  title text,
  body text
)
language sql
stable
security definer
set search_path = public
as $$
  select c.key, c.title, c.body
  from public.app_copy c
  where c.key = p_key;
$$;

grant execute on function public.get_app_copy(text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Admin helpers (web portal via authenticated admin session)
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_app_settings()
returns table (
  key text,
  value_integer integer,
  value_text text,
  description text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select s.key, s.value_integer, s.value_text, s.description, s.updated_at
  from public.app_settings s
  order by s.key;
end;
$$;

grant execute on function public.admin_list_app_settings()
  to authenticated, service_role;

create or replace function public.admin_upsert_app_setting(
  p_key text,
  p_value_integer integer,
  p_value_text text default null,
  p_description text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  if p_key is null or trim(p_key) = '' then
    raise exception 'Setting key is required';
  end if;

  if p_value_integer is null or p_value_integer < 0 then
    raise exception 'value_integer must be a non-negative integer';
  end if;

  insert into public.app_settings (key, value_integer, value_text, description)
  values (
    trim(p_key),
    p_value_integer,
    p_value_text,
    p_description
  )
  on conflict (key) do update
  set
    value_integer = excluded.value_integer,
    value_text = excluded.value_text,
    description = coalesce(excluded.description, public.app_settings.description),
    updated_at = now();
end;
$$;

grant execute on function public.admin_upsert_app_setting(text, integer, text, text)
  to authenticated, service_role;

create or replace function public.admin_list_app_copy()
returns table (
  key text,
  title text,
  body text,
  description text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select c.key, c.title, c.body, c.description, c.updated_at
  from public.app_copy c
  order by c.key;
end;
$$;

grant execute on function public.admin_list_app_copy()
  to authenticated, service_role;

create or replace function public.admin_upsert_app_copy(
  p_key text,
  p_title text,
  p_body text,
  p_description text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  if p_key is null or trim(p_key) = '' then
    raise exception 'Copy key is required';
  end if;

  insert into public.app_copy (key, title, body, description)
  values (
    trim(p_key),
    coalesce(p_title, ''),
    coalesce(p_body, ''),
    p_description
  )
  on conflict (key) do update
  set
    title = excluded.title,
    body = excluded.body,
    description = coalesce(excluded.description, public.app_copy.description),
    updated_at = now();
end;
$$;

grant execute on function public.admin_upsert_app_copy(text, text, text, text)
  to authenticated, service_role;

create or replace function public.admin_list_member_notices()
returns table (
  id uuid,
  copy_key text,
  active boolean,
  created_at timestamptz,
  recipient_count bigint,
  unseen_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.assert_admin_access();

  return query
  select
    n.id,
    n.copy_key,
    n.active,
    n.created_at,
    count(r.user_id) as recipient_count,
    count(r.user_id) filter (where r.seen_at is null) as unseen_count
  from public.member_notices n
  left join public.member_notice_recipients r on r.notice_id = n.id
  group by n.id
  order by n.created_at desc;
end;
$$;

grant execute on function public.admin_list_member_notices()
  to authenticated, service_role;
