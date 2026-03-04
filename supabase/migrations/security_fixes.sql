-- Security fixes for Supabase linter warnings
-- 1. Move pg_trgm extension from public to extensions schema
-- 2. Pin search_path on handle_updated_at and seed_quick_add_items

-- ─── 1. pg_trgm: move to extensions schema ───────────────────
-- The extensions schema is Supabase's canonical home for extensions.
ALTER EXTENSION pg_trgm SET SCHEMA extensions;

-- ─── 2. handle_updated_at: pin search_path ───────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  new.updated_at = now();
  RETURN new;
END;
$$;

-- ─── 3. seed_quick_add_items: pin search_path ────────────────
-- All table references are already fully-qualified (public.quick_add_items),
-- so adding SET search_path = '' is safe.
CREATE OR REPLACE FUNCTION public.seed_quick_add_items()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.quick_add_items (id, user_id, name, calories, protein, carbs, fat, sugar, icon, sort_order)
  VALUES
    ('default-white-rice',     NEW.id, 'White Rice',       230,  4, 50,  0,  0, E'\U0001F35A', 0),
    ('default-egg',            NEW.id, 'Egg',               78,  6,  0,  5,  0, E'\U0001F95A', 1),
    ('default-banana',         NEW.id, 'Banana',           105,  1, 27,  0, 14, E'\U0001F34C', 2),
    ('default-toast',          NEW.id, 'Toast (2 slices)', 160,  6, 30,  2,  4, E'\U0001F35E', 3),
    ('default-coffee',         NEW.id, 'Coffee with Milk', 120,  4, 10,  6,  8, E'\u2615',     4),
    ('default-chicken-breast', NEW.id, 'Chicken Breast',   165, 31,  0,  4,  0, E'\U0001F357', 5),
    ('default-apple',          NEW.id, 'Apple',             95,  0, 25,  0, 19, E'\U0001F34E', 6),
    ('default-greek-yogurt',   NEW.id, 'Greek Yogurt',     100, 10,  6,  3,  5, E'\U0001F95B', 7);
  RETURN NEW;
END;
$$;
