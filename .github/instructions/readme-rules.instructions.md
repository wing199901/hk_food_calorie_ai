---
description: "Use when working with FitCalorie app architecture, routing, database schemas, or specific UI flows (Complete Profile, Settings, Quick Add)."
applyTo: "**/*.{dart,ts,sql}"
---

# FitCalorie Architecture & Domain Rules

Based on the project's README, please adhere to these core architectural and domain rules:

## Technology Constraints

- **Routing & Presentation:** The app relies on `shared_preferences` (via `StorageService`) for local state and `fl_chart` for charts.
- **Environment:** Environment secrets are managed via `envied` + `build_runner` (generated in `lib/env/`).

## Architecture & Routing Flow

- **AppLoader (Phase):**
  - `loading` → `CircularProgressIndicator`
  - `landing` → `LandingPage`
  - `auth` → `AuthPage`
  - `app` → `AppShell`
- **AppShell (AppScreen):**
  - `completeProfile` → `CompleteProfilePage` (if `isProfileComplete == false`)
  - `bodyCheckIn` → `CheckInPage` (if `lastCheckIn != today`)
  - `main` → `MainScaffold` (Home / Analysis / + / Log / Settings)
- **Flow Integrity:** Preserve onboarding and daily check-in flow expectations. Do not bypass gates unless a product requirement explicitly says so.

## Database Schema & Logic Rules

- **user_profiles:** `user_profiles.calorie_target` must be auto-computed from TEE.
- **body_metrics:** BMI, WHtR, and TEE must be auto-computed on every daily check-in via `StorageService.addBodyMetric()`.
- **meal_records.items (JSONB):**
  - `type` must be specifically `"food"` or `"drink"`.
  - `portion_grams` is for solid food; `portion_ml` is for drinks. **They must not both be non-zero for the same item.**
- **quick_add_items:** A database trigger (`seed_quick_add_items`) auto-inserts 8 default items on new user signup. Custom items should use `id` prefixed with `custom-` or `default-`.

## UI Components & Flow Rules

- **UI Copy Language:** All in-app UI text must be English only.
- **Insight Copy Tone:** User-facing insights should be friendly casual HK English (practical and supportive).

- **Complete Profile Page (Onboarding):**
  - Must use animated progress dots.
  - Pre-fills data if `initialProfile` is provided.
  - Navigates directly to `MainScaffold` on completion (skipping the check-in step).
- **Settings Page:**
  - Must be split into 5 sections: Account Profile, Body Metrics, Data Management, About FitCalorie, and Sign Out.
  - Account Profile details are read-only by default (editable via an inline Edit button).
  - Body Metrics (weight, height, waistline, activity level) are always editable and when updated, must be saved to both `user_profiles` and `body_metrics` for today.
  - Data Management must use a Cupertino confirmation for "Clear All Meal Data".
- **Quick Add Delete Interaction (iOS-style):**
  - Long-press to enter edit mode.
  - In edit mode, show a red `×` badge on the top-left of each item; tap to delete.
  - Tap "Done" or tap outside to exit edit mode.

## AI Contract

- **Meal Analysis Endpoint:** Keep app-side meal analysis aligned with Supabase Edge Function `analyze-meal` and its structured JSON contract.
