-- Replace preferred_weight with direction-based weight goal fields.
alter table public.user_profiles
  drop column if exists preferred_weight,
  add column if not exists weight_goal text default 'maintain',
  add column if not exists goal_weight_delta numeric(5,2);
