-- Allow edge functions (service role) to manage signup OTP rows

grant select, insert, update, delete on table public.signup_email_verifications to service_role;
