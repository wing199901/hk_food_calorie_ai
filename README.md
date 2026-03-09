# FitCalorie — AI Food Calorie Tracker

AI-powered food calorie tracking app built with Flutter, Supabase, and Google Gemini 2.5 Flash. Designed for Hong Kong but works globally.

## Features

- **AI Meal Scanning** — Take a photo of your meal; Gemini AI identifies dishes, estimates portions, and calculates calories & macros
- **Quick Add** — Customizable quick-add food shortcuts with emoji icons; long-press to delete (iOS-style)
- **Daily Tracking** — Track calories, protein, carbs, fat, and sugar throughout the day
- **Weekly Analysis** — Charts showing energy intake, macros, and body metrics over 7 days
- **AI Insights** — Weekly/monthly AI-generated dietary analysis and suggestions
- **Body Metrics** — Track weight & waistline; auto-calculate BMI, WHtR, and TEE
- **Cloud Sync** — Local-first with Supabase cloud sync; works offline

## Tech Stack

| Layer            | Technology                                           |
| ---------------- | ---------------------------------------------------- |
| Mobile App       | Flutter (Dart SDK `^3.11.0`)                         |
| State Management | `flutter_riverpod ^2.6.1`                            |
| Backend / DB     | Supabase (PostgreSQL + RLS)                          |
| Serverless Logic | Supabase Edge Functions (Deno / TypeScript)          |
| AI               | Google Gemini 2.5 Flash                              |
| Auth             | Supabase Auth                                        |
| Local State      | `shared_preferences` via `StorageService`            |
| Charts           | `fl_chart ^0.70.2`                                   |
| Env Secrets      | `envied` + `build_runner` (generated `lib/env/`)     |

## Getting Started

1. Clone the repo
2. Copy `.env.example` to `lib/env/` and set your Supabase + Gemini keys
3. Run `flutter pub get && dart run build_runner build`
4. Execute `supabase/schema.sql` in your Supabase SQL Editor
5. Deploy edge functions: `supabase functions deploy`
6. Run the app: `flutter run`

## Project Structure

Feature-first layout — each screen owns its page + widgets subtree:

```
lib/
├── main.dart                        # App entry point, routing, AppShell
├── env/                             # Generated envied secrets (never edit manually)
├── core/
│   └── theme/app_theme.dart           # AppTheme colours, gradients, lightTheme
├── shared/                          # Cross-feature building blocks
│   ├── models/                        # UserProfile, Meal, BodyMetric, QuickAddItem
│   ├── providers/                     # storageProvider, supabaseProvider (Riverpod)
│   ├── services/                      # StorageService, SupabaseService, DemoData
│   └── widgets/                       # DateNavigator, DatePickerPopup, WeekNavigator
└── features/
    ├── analysis/         analysis_page.dart + widgets/ (6 chart widgets)
    ├── auth/             auth_page.dart
    ├── check_in/         check_in_page.dart
    ├── food_analysis/    add_food_page.dart + widgets/ (3 widgets)
    ├── home/             home_page.dart
    ├── log/              log_page.dart + widgets/ (meal_card, manual_meal_modal)
    ├── onboarding/       landing_page.dart, complete_profile_page.dart
    ├── profile/          profile_page.dart  (Account Profile edit page)
    └── settings/         settings_page.dart
supabase/
  schema.sql             # Database schema (source of truth)
  functions/             # Edge functions (analyze-meal, etc.)
```

## Architecture & Routing

```
AppLoader (‘Phase)
  ├── loading   → CircularProgressIndicator
  ├── landing   → LandingPage
  ├── auth      → AuthPage
  └── app       → AppShell

AppShell (AppScreen)
  ├── completeProfile → CompleteProfilePage  (isProfileComplete == false)
  ├── bodyCheckIn     → CheckInPage          (lastCheckIn != today)
  └── main            → MainScaffold         (Home / Analysis / + / Log / Settings)
```

## Database Schema

| Table              | Primary Key            | Description                                                          |
| ------------------ | ---------------------- | -------------------------------------------------------------------- |
| `user_profiles`    | `user_id` (uuid)       | Birthdate, weight, height, waistline, gender, activity level, calorie target |
| `body_metrics`     | `(user_id, date)`      | Daily weight, waistline, BMI, WHtR & TEE snapshots                   |
| `meal_records`     | `id` (text)            | AI-parsed meal entries; `items` stored as JSONB array                |
| `quick_add_items`  | `(user_id, id)` (text) | User's custom quick-add food shortcuts with icon & macros            |

### `user_profiles`

| Column               | Type         | Description                                                   |
| -------------------- | ------------ | ------------------------------------------------------------- |
| `user_id`            | uuid (FK)    | Primary key — references `auth.users`                         |
| `birthdate`          | date         | Date of birth (YYYY-MM-DD)                                    |
| `weight`             | numeric(5,2) | Body weight in kg                                             |
| `height`             | numeric(5,2) | Height in cm                                                  |
| `waistline`          | numeric(5,2) | Waist circumference in cm                                     |
| `gender`             | text         | `'male'` \| `'female'` \| `'other'`                           |
| `activity_level`     | integer      | 0=sedentary … 4=very-active (mapped to string in client)      |
| `calorie_target`     | integer      | Daily kcal goal (auto-computed from TEE)                      |
| `last_check_in_date` | date         | Date of last body check-in                                    |

### `body_metrics`

BMI, WHtR, and TEE are auto-computed on every daily check-in via `StorageService.addBodyMetric()`.

| Column     | Type         | Description                                        |
| ---------- | ------------ | -------------------------------------------------- |
| `user_id`  | uuid (FK)    | User ID                                            |
| `date`     | date         | Date (composite primary key with `user_id`)        |
| `weight`   | numeric(5,2) | Body weight in kg                                  |
| `waistline`| numeric(5,2) | Waist circumference in cm                          |
| `bmi`      | numeric(4,1) | Body Mass Index — auto-computed                    |
| `whtr`     | numeric(3,2) | Waist-to-Height Ratio — auto-computed              |
| `tee`      | integer      | Total Energy Expenditure (kcal) — auto-computed    |

### `quick_add_items`

On new user signup, a DB trigger (`seed_quick_add_items`) auto-inserts 8 default items.

| Column       | Type      | Description                           |
| ------------ | --------- | ------------------------------------- |
| `id`         | text      | Unique ID (`default-*` or `custom-*`) |
| `user_id`    | uuid (FK) | Owner                                 |
| `name`       | text      | Food name                             |
| `calories`   | integer   | Calories (kcal)                       |
| `protein`    | integer   | Protein (g)                           |
| `carbs`      | integer   | Carbohydrates (g)                     |
| `fat`        | integer   | Fat (g)                               |
| `sugar`      | integer   | Sugar (g)                             |
| `icon`       | text      | Emoji icon                            |
| `sort_order` | integer   | Display order                         |

### `meal_records.items` — JSONB element schema

```json
{
  "name_zh": "蛋撻",
  "name_en": "Egg Tart",
  "type": "food",
  "portion_size": 1,
  "portion_unit": "piece",
  "portion_grams": 75,
  "portion_ml": null,
  "calories": 220,
  "protein": 4,
  "carbs": 28,
  "fat": 10,
  "sugar": 12,
  "confidence": 0.95
}
```

> `type` is `"food"` or `"drink"`. `portion_grams` is for solid food; `portion_ml` is for drinks — they must not both be non-zero for the same item.

The source of truth is [`supabase/schema.sql`](supabase/schema.sql). See [.github/copilot-instructions.md](.github/copilot-instructions.md) for full coding conventions and visual style guidelines.
