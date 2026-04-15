# FitCalorie — AI Food Calorie Tracker

AI-powered food calorie tracking app built with Flutter, Supabase, and Google Gemini 2.5 Flash. Designed for Hong Kong but works globally.

## Features

- **AI Meal Scanning** — Take a photo of your meal; app uploads to a private Supabase Storage bucket, sends the storage path to edge function for analysis, then requires user confirmation before saving
- **Human-in-the-Loop Review** — If AI output is inaccurate, user can edit meal name/macros, confirm corrected values, and save with feedback marked as corrected
- **Quick Add** — Customizable quick-add food shortcuts with emoji icons; long-press to delete (iOS-style)
- **Daily Tracking** — Track calories, protein, carbs, fat, and sugar throughout the day
- **Weekly Analysis** — Charts showing energy intake, macros, and body metrics over 7 days
- **AI Insights** — Weekly/monthly AI-generated dietary analysis and suggestions
- **Body Metrics** — Track weight, preferred weight, and waistline; auto-calculate BMI, WHtR, and TEE-based intake targets
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
4. Execute `supabase/schema.sql` in your Supabase SQL Editor (or run all files in `supabase/migrations/`)
5. Confirm `meal-images` bucket exists as a private bucket (it is auto-created by SQL migration)
6. Deploy edge functions: `supabase functions deploy`
7. Run the app: `make run`

### Local Reset + Postman Fixtures

Postman image fixtures (for `{{userId}}/postman/egg-tart-1.jpg` and `{{userId}}/postman/egg-tart-3.jpg`) are binary objects in Supabase Storage, so they are provisioned right after SQL seed.

1. Reset local DB and provision fixtures in one step: `make db-reset`
2. If needed, provision fixtures only: `make postman-fixtures`
3. Override fixture user id when needed:
   `make postman-fixtures SUPABASE_TEST_USER_ID=<your-user-uuid>`

## Testing

Run static analysis and all tests before merging changes:

1. `dart analyze`
2. `flutter test`
3. `flutter test test/e2e/app_test.dart`

Notes:

- Unit and widget tests are organized in `test/unit` and `test/widget`.
- End-to-end coverage is in `test/e2e/app_test.dart` using `integration_test`.
- `postman/run-local-tests.sh` auto-provisions fixtures for the authenticated `userId` by default (set `POSTMAN_SETUP_FIXTURES=0` to skip).

## Developer Guidelines & Rules

All deep architectural rules, database schema details, and UI flow constraints have been extracted to instructions for AI agents and developer reference.

- **Coding Rules**: Read [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for codebase conventions, file structures, and Dart/Flutter visual guidelines.
- **App Architecture & Flow**: See [`.github/instructions/readme-rules.instructions.md`](.github/instructions/readme-rules.instructions.md) for routing (`AppLoader` rules), edge cases, and UI rules like the settings page structure and iOS-style interactions.
- **Database Schema**: The absolute source of truth is [`supabase/schema.sql`](supabase/schema.sql). Never bypass Row Level Security policies.
