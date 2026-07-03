-- Enable Supabase Realtime for orders and reward transactions

alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.reward_transactions;
