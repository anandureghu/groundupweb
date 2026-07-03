-- Email OTP verification before customer sign-up

create table public.signup_email_verifications (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  otp_hash text not null,
  attempts integer not null default 0,
  expires_at timestamptz not null,
  verified_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create index signup_email_verifications_email_created_at_idx
  on public.signup_email_verifications (email, created_at desc);
create index signup_email_verifications_expires_at_idx
  on public.signup_email_verifications (expires_at);
alter table public.signup_email_verifications enable row level security;
-- No client policies: edge functions use service role only.

create or replace function public.purge_expired_signup_email_verifications()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.signup_email_verifications
  where created_at < now() - interval '24 hours';
end;
$$;
