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

See [.github/copilot-instructions.md](.github/copilot-instructions.md) for full coding conventions, visual style guidelines, and DB schema details.
