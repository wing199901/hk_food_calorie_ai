-- Migration: Add quick_add_items table
-- Apply via: psql $DB_URL -f supabase/migrations/quick_add_items.sql

CREATE TABLE IF NOT EXISTS public.quick_add_items (
  id              text NOT NULL,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name            text NOT NULL,
  calories        integer NOT NULL DEFAULT 0,
  protein         integer DEFAULT 0,
  carbs           integer DEFAULT 0,
  fat             integer DEFAULT 0,
  sugar           integer DEFAULT 0,
  icon            text NOT NULL DEFAULT E'\U0001F37D\uFE0F',
  sort_order      integer DEFAULT 0,
  created_at      timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, id)
);

ALTER TABLE public.quick_add_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own quick add items" ON public.quick_add_items;
DROP POLICY IF EXISTS "Users can insert their own quick add items" ON public.quick_add_items;
DROP POLICY IF EXISTS "Users can update their own quick add items" ON public.quick_add_items;
DROP POLICY IF EXISTS "Users can delete their own quick add items" ON public.quick_add_items;

CREATE POLICY "Users can view their own quick add items"
  ON public.quick_add_items FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own quick add items"
  ON public.quick_add_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own quick add items"
  ON public.quick_add_items FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own quick add items"
  ON public.quick_add_items FOR DELETE
  USING (auth.uid() = user_id);

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

DROP TRIGGER IF EXISTS on_auth_user_created_seed_quick_add ON auth.users;
CREATE TRIGGER on_auth_user_created_seed_quick_add
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.seed_quick_add_items();
