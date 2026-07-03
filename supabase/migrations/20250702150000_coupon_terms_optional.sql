-- Make coupon terms optional

alter table public.coupon_definitions
  alter column terms_content drop not null;
create or replace function public.upsert_coupon_admin(
  p_id uuid default null,
  p_slug text default null,
  p_title text default null,
  p_description text default null,
  p_discount_type text default null,
  p_discount_percent integer default null,
  p_discount_amount_cents integer default null,
  p_min_order_cents integer default null,
  p_max_discount_cents integer default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_max_total_redemptions integer default null,
  p_per_member_max_uses integer default 1,
  p_validity_days_after_assign integer default null,
  p_terms_content text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_title text;
  v_terms text;
  v_id uuid;
begin
  perform public.assert_admin_access();

  v_slug := public.validate_coupon_slug(p_slug);
  v_title := trim(p_title);
  v_terms := nullif(trim(coalesce(p_terms_content, '')), '');

  if v_title = '' then
    raise exception 'Title is required';
  end if;

  if p_discount_type not in ('percent', 'fixed_amount') then
    raise exception 'Invalid discount type: %', p_discount_type;
  end if;

  if p_discount_type = 'percent' and (p_discount_percent is null or p_discount_percent < 1 or p_discount_percent > 100) then
    raise exception 'Percent coupons require a discount between 1 and 100';
  end if;

  if p_discount_type = 'fixed_amount' and (p_discount_amount_cents is null or p_discount_amount_cents <= 0) then
    raise exception 'Fixed amount coupons require a positive discount amount';
  end if;

  if p_starts_at is not null and p_ends_at is not null and p_ends_at <= p_starts_at then
    raise exception 'End date must be after start date';
  end if;

  if p_per_member_max_uses is null or p_per_member_max_uses < 1 then
    raise exception 'Per-member max uses must be at least 1';
  end if;

  if p_id is null then
    insert into public.coupon_definitions (
      slug,
      title,
      description,
      discount_type,
      discount_percent,
      discount_amount_cents,
      min_order_cents,
      max_discount_cents,
      starts_at,
      ends_at,
      max_total_redemptions,
      per_member_max_uses,
      validity_days_after_assign,
      terms_content,
      is_active
    )
    values (
      v_slug,
      v_title,
      coalesce(trim(p_description), ''),
      p_discount_type,
      case when p_discount_type = 'percent' then p_discount_percent else null end,
      case when p_discount_type = 'fixed_amount' then p_discount_amount_cents else null end,
      p_min_order_cents,
      p_max_discount_cents,
      p_starts_at,
      p_ends_at,
      p_max_total_redemptions,
      p_per_member_max_uses,
      p_validity_days_after_assign,
      v_terms,
      coalesce(p_is_active, true)
    )
    returning id into v_id;
  else
    update public.coupon_definitions
    set
      slug = v_slug,
      title = v_title,
      description = coalesce(trim(p_description), ''),
      discount_type = p_discount_type,
      discount_percent = case when p_discount_type = 'percent' then p_discount_percent else null end,
      discount_amount_cents = case when p_discount_type = 'fixed_amount' then p_discount_amount_cents else null end,
      min_order_cents = p_min_order_cents,
      max_discount_cents = p_max_discount_cents,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      max_total_redemptions = p_max_total_redemptions,
      per_member_max_uses = p_per_member_max_uses,
      validity_days_after_assign = p_validity_days_after_assign,
      terms_content = v_terms,
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'Coupon not found: %', p_id;
    end if;
  end if;

  return v_id;
end;
$$;
