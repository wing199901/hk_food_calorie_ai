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
| State Management | `flutter_riverpod ^2.6.1`                        |
| Backend / DB     | Supabase (PostgreSQL + RLS)                      |
| Serverless Logic | Supabase Edge Functions (Deno / TypeScript)      |
| AI               | Google Gemini 2.5 Flash                          |
| Auth             | Supabase Auth                                    |
| Local State      | `shared_preferences` via `StorageService`        |
| Charts           | `fl_chart ^0.70.2`                               |
| Env Secrets      | `envied` + `build_runner` (generated `lib/env/`) |

## Getting Started

1. Clone the repo
2. Copy `.env.example` to `lib/env/` and set your Supabase + Gemini keys
3. Run `flutter pub get && dart run build_runner build`
4. Execute `supabase/schema.sql` in your Supabase SQL Editor
5. Deploy edge functions: `supabase functions deploy`
6. Run the app: `make run`

## Testing

Run static analysis and all tests before merging changes:

1. `dart analyze`
2. `flutter test`
3. `flutter test test/e2e/app_test.dart`

Notes:

- Unit and widget tests are organized in `test/unit` and `test/widget`.
- End-to-end coverage is in `test/e2e/app_test.dart` using `integration_test`.

## Developer Guidelines & Rules

All deep architectural rules, database schema details, and UI flow constraints have been extracted to instructions for AI agents and developer reference.

- **Coding Rules**: Read [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for codebase conventions, file structures, and Dart/Flutter visual guidelines.
- **App Architecture & Flow**: See [`.github/instructions/readme-rules.instructions.md`](.github/instructions/readme-rules.instructions.md) for routing (`AppLoader` rules), edge cases, and UI rules like the settings page structure and iOS-style interactions.
- **Database Schema**: The absolute source of truth is [`supabase/schema.sql`](supabase/schema.sql). Never bypass Row Level Security policies.
