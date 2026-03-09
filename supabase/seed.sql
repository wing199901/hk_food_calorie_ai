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
-- (trigger only fires on INSERT, not on seed — so we insert manually)
-- ─────────────────────────────────────────────────────────────
insert into public.quick_add_items (id, user_id, name, calories, protein, carbs, fat, sugar, icon, sort_order)
values
  ('default-white-rice',     '00000000-0000-0000-0000-000000000001', 'White Rice',       230,  4, 50,  0,  0, '🍚', 0),
  ('default-egg',            '00000000-0000-0000-0000-000000000001', 'Egg',               78,  6,  0,  5,  0, '🥚', 1),
  ('default-banana',         '00000000-0000-0000-0000-000000000001', 'Banana',           105,  1, 27,  0, 14, '🍌', 2),
  ('default-toast',          '00000000-0000-0000-0000-000000000001', 'Toast (2 slices)', 160,  6, 30,  2,  4, '🍞', 3),
  ('default-coffee',         '00000000-0000-0000-0000-000000000001', 'Coffee with Milk', 120,  4, 10,  6,  8, '☕', 4),
  ('default-chicken-breast', '00000000-0000-0000-0000-000000000001', 'Chicken Breast',   165, 31,  0,  4,  0, '🍗', 5),
  ('default-apple',          '00000000-0000-0000-0000-000000000001', 'Apple',             95,  0, 25,  0, 19, '🍎', 6),
  ('default-greek-yogurt',   '00000000-0000-0000-0000-000000000001', 'Greek Yogurt',     100, 10,  6,  3,  5, '🥛', 7)
on conflict (user_id, id) do nothing;
