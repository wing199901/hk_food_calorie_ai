-- ============================================================
-- FitCalorie — Seed Data (local development only)
-- Applied automatically by: supabase db reset
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- Test user in auth.users
-- email: test@example.com  password: 12345678
-- uid:   00000000-0000-0000-0000-000000000001
-- ─────────────────────────────────────────────────────────────
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  recovery_sent_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'test@example.com',
  extensions.crypt('12345678', extensions.gen_salt('bf', 10)),
  current_timestamp,
  current_timestamp,
  current_timestamp,
  '{"provider":"email","providers":["email"]}',
  '{}',
  current_timestamp,
  current_timestamp,
  '',
  '',
  '',
  ''
) on conflict (id) do nothing;

-- Required identity row for Supabase auth
-- Uses SELECT pattern from auth.users so user_id always matches
insert into auth.identities (
  id,
  user_id,
  provider_id,
  provider,
  identity_data,
  created_at,
  updated_at,
  last_sign_in_at
) (
  select
    extensions.uuid_generate_v4(),
    id,
    id::text,
    'email',
    format('{"sub":"%s","email":"%s"}', id::text, email)::jsonb,
    current_timestamp,
    current_timestamp,
    current_timestamp
  from auth.users
  where email = 'test@example.com'
) on conflict (provider, provider_id) do nothing;

-- ─────────────────────────────────────────────────────────────
-- Default quick-add items for test user
-- (Handled automatically by the trigger on auth.users when a new user is inserted)
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- Demo Data: Body Metrics
-- ─────────────────────────────────────────────────────────────
insert into public.body_metrics (user_id, date, created_at, weight, waistline)
values
  ('00000000-0000-0000-0000-000000000001', (current_date - interval '30 days')::date, (current_date - interval '30 days')::date + time '09:00', 72.5, 85),
  ('00000000-0000-0000-0000-000000000001', (current_date - interval '20 days')::date, (current_date - interval '20 days')::date + time '09:00', 71.8, 84),
  ('00000000-0000-0000-0000-000000000001', (current_date - interval '10 days')::date, (current_date - interval '10 days')::date + time '09:00', 71.2, 83),
  ('00000000-0000-0000-0000-000000000001', (current_date - interval '5 days')::date, (current_date - interval '5 days')::date + time '09:00', 70.8, 82.5),
  ('00000000-0000-0000-0000-000000000001', (current_date - interval '1 day')::date, (current_date - interval '1 day')::date + time '09:00', 70.5, 82)
on conflict (user_id, date, created_at) do nothing;

-- ─────────────────────────────────────────────────────────────
-- Demo Data: Meal Records
-- ─────────────────────────────────────────────────────────────
insert into public.meal_records (
  id, user_id, date, created_at, image_base64,
  total_calories, total_protein, total_carbs, total_fat, total_sugar,
  items
)
values
  (
    'demo-1', '00000000-0000-0000-0000-000000000001', current_date, (current_date + interval '8 hours'),
    'https://images.unsplash.com/photo-1555126634-323283e090fa?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    520, 8, 62, 26, 28,
    '[{"name": "Pineapple Bun + Milk Tea", "calories": 520, "protein": 8, "carbs": 62, "fat": 26, "sugar": 28, "portion": "1 serving", "confidence": 1.0}]'::jsonb
  ),
  (
    'demo-2', '00000000-0000-0000-0000-000000000001', current_date, (current_date + interval '12 hours'),
    'https://images.unsplash.com/photo-1569058242567-93de6f36f8eb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    680, 32, 85, 22, 8,
    '[{"name": "Char Siu Rice", "calories": 680, "protein": 32, "carbs": 85, "fat": 22, "sugar": 8, "portion": "1 serving", "confidence": 1.0}]'::jsonb
  ),
  (
    'demo-3', '00000000-0000-0000-0000-000000000001', current_date - interval '1 day', (current_date - interval '1 day' + interval '12 hours'),
    'https://images.unsplash.com/photo-1583032015879-e5022cb87c3b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    380, 18, 48, 12, 4,
    '[{"name": "Wonton Noodles", "calories": 380, "protein": 18, "carbs": 48, "fat": 12, "sugar": 4, "portion": "1 serving", "confidence": 1.0}]'::jsonb
  ),
  (
    'demo-4', '00000000-0000-0000-0000-000000000001', current_date - interval '2 days', (current_date - interval '2 days' + interval '9 hours'),
    'https://images.unsplash.com/photo-1582106245687-cbb466a9f07f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    220, 4, 28, 10, 12,
    '[{"name": "Egg Tart", "calories": 220, "protein": 4, "carbs": 28, "fat": 10, "sugar": 12, "portion": "1 serving", "confidence": 1.0}]'::jsonb
  )
on conflict (id) do nothing;
