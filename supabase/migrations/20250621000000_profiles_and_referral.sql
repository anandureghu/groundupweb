-- Profiles table for Groundup Society members
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null,
  last_name text not null,
  email text not null unique,
  mobile_number text not null,
  birthday date not null,
  marketing_opt_in boolean not null default false,
  referral_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_referral_code_idx on public.profiles (referral_code);
-- Generate readable referral codes: GS-XXXXXX
create or replace function public.generate_referral_code()
returns trigger
language plpgsql
as $$
declare
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text := 'GS-';
  i integer;
begin
  if new.referral_code is not null and new.referral_code <> '' then
    return new;
  end if;

  loop
    code := 'GS-';
    for i in 1..6 loop
      code := code || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    end loop;

    exit when not exists (
      select 1 from public.profiles where referral_code = code
    );
  end loop;

  new.referral_code := code;
  return new;
end;
$$;
create trigger profiles_set_referral_code
before insert on public.profiles
for each row
execute function public.generate_referral_code();
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();
alter table public.profiles enable row level security;
create policy "Users can view own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);
create policy "Users can insert own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);
create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
