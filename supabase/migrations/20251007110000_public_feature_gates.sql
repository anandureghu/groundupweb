-- Public (anon) read of coming-soon message for the marketing website

create or replace function public.get_public_feature_gates()
returns table (
  default_mode text,
  coming_soon_message text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_gates jsonb;
begin
  select coalesce(value_text::jsonb, '{}'::jsonb)
  into v_gates
  from public.app_settings
  where key = 'feature_gates';

  return query
  select
    coalesce(v_gates->>'defaultMode', 'coming_soon') as default_mode,
    coalesce(
      nullif(trim(v_gates->>'comingSoonMessage'), ''),
      'We are preparing something special. Check back soon.'
    ) as coming_soon_message;
end;
$$;

grant execute on function public.get_public_feature_gates() to anon, authenticated, service_role;
