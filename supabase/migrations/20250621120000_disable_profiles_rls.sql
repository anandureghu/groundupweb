-- Disable RLS on profiles for development (signup was blocked by policies)
drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
alter table public.profiles disable row level security;
grant select, insert, update, delete on table public.profiles to anon, authenticated, service_role;
