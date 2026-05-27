-- Demo data for current week (Sunday -> today)
-- Local-only snippet for user_id: 00000000-0000-0000-0000-000000000001
-- Safe to run multiple times (deterministic ids + ON CONFLICT DO NOTHING).
-- Single-statement version for `supabase db query`.

with start_sun as (
  select
    (current_date - (extract(dow from current_date)::int) * interval '1 day')::date
      as start_date
),
days as (
  select generate_series(start_date, current_date, interval '1 day')::date as day_date
  from start_sun
),
base as (
  select
    day_date,
    (day_date - (select start_date from start_sun))::int as day_index
  from days
),
metrics as (
  select
    day_date as metric_date,
    (71.0 - (day_index * 0.1))::numeric(5,2) as weight,
    (82.0 - (day_index * 0.05))::numeric(5,2) as waistline,
    time '07:45' as metric_time
  from base
),
ins_metrics as (
  insert into public.body_metrics (
    user_id,
    date,
    created_at,
    weight,
    waistline
  )
  select
    '00000000-0000-0000-0000-000000000001',
    metric_date,
    metric_date + metric_time,
    weight,
    waistline
  from metrics
  on conflict (user_id, date, created_at) do nothing
  returning 1
),
meals as (
  select
    day_date as meal_date,
    1 as slot,
    (420 + ((day_index % 3) - 1) * 30) as total_calories,
    (18 + ((day_index % 3) - 1) * 2) as total_protein,
    (55 + ((day_index % 3) - 1) * 4) as total_carbs,
    (14 + ((day_index % 3) - 1) * 2) as total_fat,
    (12 + ((day_index % 3) - 1) * 2) as total_sugar,
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400'
      as image_url,
    jsonb_build_array(
      jsonb_build_object(
        'name', 'Macaroni Soup + Milk Tea',
        'calories', (420 + ((day_index % 3) - 1) * 30),
        'protein', (18 + ((day_index % 3) - 1) * 2),
        'carbs', (55 + ((day_index % 3) - 1) * 4),
        'fat', (14 + ((day_index % 3) - 1) * 2),
        'sugar', (12 + ((day_index % 3) - 1) * 2),
        'portion', '1 set',
        'confidence', 1.0
      )
    ) as items,
    time '08:15' as meal_time
  from base

  union all

  select
    day_date as meal_date,
    2 as slot,
    (680 + ((day_index % 3) - 1) * 40) as total_calories,
    (32 + ((day_index % 3) - 1) * 3) as total_protein,
    (85 + ((day_index % 3) - 1) * 5) as total_carbs,
    (22 + ((day_index % 3) - 1) * 3) as total_fat,
    (8 + ((day_index % 3) - 1) * 1) as total_sugar,
    'https://images.unsplash.com/photo-1569058242567-93de6f36f8eb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400'
      as image_url,
    jsonb_build_array(
      jsonb_build_object(
        'name', 'Char Siu Rice',
        'calories', (680 + ((day_index % 3) - 1) * 40),
        'protein', (32 + ((day_index % 3) - 1) * 3),
        'carbs', (85 + ((day_index % 3) - 1) * 5),
        'fat', (22 + ((day_index % 3) - 1) * 3),
        'sugar', (8 + ((day_index % 3) - 1) * 1),
        'portion', '1 serving',
        'confidence', 1.0
      )
    ) as items,
    time '19:00' as meal_time
  from base
),
ins_meals as (
  insert into public.meal_records (
    id,
    user_id,
    meal_date,
    created_at,
    image_url,
    total_calories,
    total_protein,
    total_carbs,
    total_fat,
    total_sugar,
    items
  )
  select
    format('demo-week-%s-%s', to_char(meal_date, 'YYYYMMDD'), slot),
    '00000000-0000-0000-0000-000000000001',
    meal_date,
    meal_date + meal_time,
    image_url,
    total_calories::int,
    total_protein::int,
    total_carbs::int,
    total_fat::int,
    total_sugar::int,
    items
  from meals
  on conflict (id) do nothing
  returning 1
)
select
  (select count(*) from ins_metrics) as inserted_metrics,
  (select count(*) from ins_meals) as inserted_meals;

-- Cleanup (optional):
-- delete from public.meal_records
-- where user_id = '00000000-0000-0000-0000-000000000001'
--   and id like 'demo-week-%';
-- delete from public.body_metrics
-- where user_id = '00000000-0000-0000-0000-000000000001'
--   and created_at::date >=
--     (current_date - (extract(dow from current_date)::int) * interval '1 day')::date;
