-- Switch goal-direction fields to a single target_weight field.
alter table public.user_profiles
  add column if not exists target_weight numeric(5,2);

update public.user_profiles
set target_weight = case
  when weight is null then null
  when weight_goal = 'lose' and goal_weight_delta is not null and goal_weight_delta > 0
    then weight - goal_weight_delta
  when weight_goal = 'gain' and goal_weight_delta is not null and goal_weight_delta > 0
    then weight + goal_weight_delta
  else weight
end
where target_weight is null;

alter table public.user_profiles
  drop column if exists weight_goal,
  drop column if exists goal_weight_delta;
