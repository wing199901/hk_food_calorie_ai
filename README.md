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

| Layer            | Technology                                       |
| ---------------- | ------------------------------------------------ |
| Mobile App       | Flutter (Dart SDK `^3.11.0`)                     |
| Backend / DB     | Supabase (PostgreSQL + RLS)                      |
| Serverless Logic | Supabase Edge Functions (Deno / TypeScript)      |
| AI               | Google Gemini 2.5 Flash                          |
| Auth             | Supabase Auth + Google Sign-In                   |
| Local State      | `shared_preferences` via `StorageService`        |
| Charts           | `fl_chart`                                       |

## Getting Started

1. Clone the repo
2. Copy `.env.example` to `lib/env/` and set your Supabase + Gemini keys
3. Run `flutter pub get && dart run build_runner build`
4. Execute `supabase/schema.sql` in your Supabase SQL Editor
5. Deploy edge functions: `supabase functions deploy`
6. Run the app: `flutter run`

## Project Structure

```
lib/
  main.dart              # App entry, auth flow, navigation
  env/                   # Generated environment variables (envied)
  models/                # Data models (Meal, UserProfile, BodyMetric, QuickAddItem)
  pages/                 # UI pages (Home, Analysis, Log, Settings, AddFood, etc.)
  services/              # StorageService (local), SupabaseService (cloud)
  theme/                 # AppTheme colours, typography, gradients
  widgets/               # Reusable UI components
supabase/
  schema.sql             # Database schema (source of truth)
  functions/             # Edge functions (analyze-meal, etc.)
```

See [guidelines.md](guidelines.md) for full project conventions and rules.
