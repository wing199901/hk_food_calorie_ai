-- Add preferred weight so calorie intake range can use current vs goal TEE.

alter table public.user_profiles
  add column if not exists preferred_weight numeric(5,2);
