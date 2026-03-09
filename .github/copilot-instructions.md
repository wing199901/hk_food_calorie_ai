# FitCalorie — Project Guidelines

## Overview

**FitCalorie** is an AI-powered food calorie tracking app designed for Hong Kong users. Users photograph their meals (dim sum (點心), cha chaan teng (茶餐廳), BBQ meat (燒味), Western, Japanese/Korean, Southeast Asian, desserts, drinks, etc.) and Google Gemini automatically identifies dishes, estimates real portion sizes, calculates calories and macronutrients, and stores daily records.

---

See [README.md](../README.md) for the full tech stack, project structure, and routing diagram.

---

## Database Schema

### Tables

| Table              | Primary Key            | Description                                                                        |
| ------------------ | ---------------------- | ---------------------------------------------------------------------------------- |
| `user_profiles`    | `user_id` (uuid)       | Birthdate, weight, height, waistline, gender, activity level, calorie target        |
| `body_metrics`     | `(user_id, date)`      | Daily weight, waistline, BMI, WHtR & TEE snapshots                                 |
| `meal_records`     | `id` (text)            | AI-parsed meal entries; `items` stored as JSONB array                              |
| `quick_add_items`  | `(user_id, id)` (text) | User's custom quick-add food shortcuts with icon & macros                          |

See [README.md § Database Schema](../README.md#database-schema) for the full per-column breakdown. The source of truth is [`supabase/schema.sql`](../supabase/schema.sql).

> `body_metrics`: BMI, WHtR, and TEE are auto-computed and stored on every daily check-in via `StorageService.addBodyMetric()`.

### iOS-style Quick Add Delete Interaction

- Long-press a quick-add item to enter edit mode
- In edit mode, a red × badge appears on the top-left of each item; tap to delete
- Tap "Done" or tap outside to exit edit mode
- New items are added via a bottom sheet (emoji icon picker + calories / macros)

### `meal_records.items` — JSONB element schema

Each element matches the structure returned by the Gemini prompt in `analyze-meal`:

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

### RLS

All tables must enforce Row Level Security. All policies use `auth.uid() = user_id`. Never bypass RLS on the client side.

---

## Edge Functions

All functions accept **POST** requests with `Authorization: Bearer <jwt>`. See [supabase/functions/README.md](../supabase/functions/README.md) for the full function list, API request/response schemas, and deployment instructions.

### AI Structured Output (`analyze-meal`)

`analyze-meal` uses Gemini **Structured Output** (`responseMimeType` + `responseSchema`) to guarantee valid JSON — no manual markdown fence stripping needed.

See [`supabase/functions/analyze-meal/index.ts`](../supabase/functions/analyze-meal/index.ts) for the full `SYSTEM_INSTRUCTION`, `RESPONSE_SCHEMA`, and `generationConfig` (`temperature: 0.2`, `maxOutputTokens: 2048`).

### Image Handling (client-side compression rules)

Images **must be compressed** before sending to the Edge Function:

- Use the `image` package (`img.copyResize` + `encodeJpg quality: 85`)
- Limit longest edge to 1280px
- Convert to base64 after compression
- Target size: < 1.5 MB (post-base64)
- Format must be JPEG

---

## Project Visual Style

The app uses a clean iOS-style design. All design decisions must follow the rules below.

### Colours (`AppTheme`)

See [`lib/core/theme/app_theme.dart`](../lib/core/theme/app_theme.dart) for the full colour token definitions. Key tokens: `primary` (#10B981 green), `accent` (#FF6B35 orange), `background` (#F8FAFB), `destructive` (#EF4444).

### Typography & Shape

- Font family: `SF Pro Display`
- Cards: `borderRadius: 16`, elevation `0`, thin `border` side
- Buttons: `borderRadius: 16`, vertical padding `16`, elevation `2`
- Inputs: `borderRadius: 12`, filled white, focused border `primary` width `2`
- Gradients: `AppTheme.primaryGradient` (green → green) or `AppTheme.primaryToAccent` (green → orange)

### 8-Point Grid System

All spacing, sizing, and padding must be **multiples of 8**; fine-tune with **4**:

| Token | Value | Usage                                           |
| ----- | ----- | ----------------------------------------- |
| `4`   | 4px   | Fine gap between icon and text, badge padding   |
| `8`   | 8px   | Between elements in a group, chip inner gap     |
| `12`  | 12px  | Small card inner gap, between list items        |
| `16`  | 16px  | Card padding, section inner gap, input padding  |
| `24`  | 24px  | Between cards, section vertical gap             |
| `32`  | 32px  | Page top space, large section divider           |
| `48`  | 48px  | Hero block vertical, empty-state illustration   |
| `64`  | 64px  | Page-level large whitespace                     |

**Rules:**

- Never use odd values (e.g. `5`, `7`, `13`)
- Never use `3` or `6` — use `4` or `8` instead
- Icon sizes: `16`, `20`, `24`, `32`, `40`, `48`
- All `SizedBox` / `Padding` / `margin` must use the token values above
- `BorderRadius` values: `4`, `8`, `12`, `16`, `24` — never non-grid values like `10` or `15`

```dart
// Correct
Padding(padding: EdgeInsets.all(16))
SizedBox(height: 24)
BorderRadius.circular(16)

// Wrong
Padding(padding: EdgeInsets.all(15))
SizedBox(height: 22)
BorderRadius.circular(10)
```

### Chart Style (`analysis_page`)

- iOS Screen Time-style card layout
- Each chart card has a floating title badge at the top
- Bar chart uses SMTWTFS x-axis labels
- `maxY` rounds up to the nearest 2000; `midY = maxY / 2` is always a whole-number in k
- Summary chips replace legend items
- Use `ExtraLinesData` to add horizontal lines at `y=0` and `y=maxY`
- Tapping a bar updates the card subtitle to the selected date
- Expanded detail panel has no close icon and no footer hint text

### General UI Rules

- Never hardcode colours — always use `AppTheme.*`
- Never hardcode text styles — pull from `Theme.of(context).textTheme`
- All spacing follows the **8-Point Grid System** (see above)
- Use `BorderRadius.circular()` with grid values only (4, 8, 12, 16, 24)
- All UI text defaults to **English**
- **All confirmation dialogs must use `CupertinoAlertDialog`** (iOS style); destructive actions use `isDestructiveAction: true`
- **All date pickers must use `CupertinoDatePicker`** inside `showCupertinoModalPopup` — never use Material `showDatePicker`
- **Health Scores (BMI / WHtR / TEE) are displayed on the Analysis Page only** — not on Settings Page
- Home Page circular progress indicator: **220×220** size, kcal font **44px**, `strokeWidth: 14`
- Analysis Page Insights use a **casual Hong Kong English tone** (e.g. "Your calories are a bit high today la~", "So consistent this week!", "Protein is your best friend 💪")

---

## Coding Conventions

- **Dart**: Follow `flutter_lints`; prefer `const` constructors + trailing commas
- **State Management**: All pages must extend `ConsumerStatefulWidget`; use `ref.read(storageProvider)` for one-off reads, `ref.watch(storageProvider)` to rebuild on storage changes
- **Null safety**: Use `if (x != null) x` inside collections — avoid `?` null-aware collection element syntax (not supported by the current SDK)
- **Services**: All Supabase calls must go through `SupabaseService`; never call `supabase.from()` directly inside a page widget
- **Edge functions**: Place shared utilities in `supabase/functions/_shared/`; errors must use the shared `errorResponse` helper
- **Schema**: `supabase/schema.sql` is the single source of truth — any DB changes must be reflected there **and** copied into `supabase/migrations/20240101000000_initial_schema.sql`, then applied to the local Supabase instance by running:
  ```bash
  supabase db reset
  ```
  This resets and re-applies all migrations against the local Supabase container. The `seed.sql` warning can be ignored.

---

## Architecture — Feature-First Clean Structure

The project follows a **feature-first** layout under `lib/`. See [README.md](../README.md) for the full directory tree and routing state machine.

### Architecture Rules

- **Feature folder owns its page + widgets subtree.** Never import from one feature into another — share through `shared/` instead.
- **One page file per route.** If a page grows large, extract child widgets into `features/<name>/widgets/`.
- **`core/` has zero feature/shared dependencies.** Only flutter SDK + `dart:` packages allowed.
- **Providers live in `shared/providers/`.** Both providers are `ChangeNotifierProvider` and are overridden in `main()` with pre-initialised instances.

---

## `UserProfile` Model

See [`lib/shared/models/user_profile.dart`](../lib/shared/models/user_profile.dart) for the full model. Key rules:

- Fields: `birthdate` (YYYY-MM-DD), `weight`, `height`, `waistline`, `gender`, `activityLevel`.
- `age` is a **computed getter** derived from `birthdate`; never store or accept it as input.
- `isProfileComplete` (`birthdate != null && gender != null && height != null && weight != null`) drives the onboarding redirect in `AppShell`.

---

## Settings Page Design

`settings_page.dart` is split into **five sections**:

| # | Section | Behaviour |
|---|---------|-----------|
| 1 | **Account Profile** | Tappable nav row → navigates to `ProfilePage` (dedicated page). On `ProfilePage`, profile details (`birthdate`, `gender`, `age`) are **read-only by default**. An **Edit** button sits inline to the right of the "Profile Details" section title; tap to unlock fields, tap **Save** to persist, tap **Cancel** to discard. |
| 2 | **Body Metrics** | `weight`, `height`, `waistline`, `activityLevel` — **always editable**. Big green **"Update"** button (`AppTheme.primary`) saves to both `user_profiles` and `body_metrics` for today's date. |
| 3 | **Data Management** | "Clear All Meal Data" — `CupertinoAlertDialog` confirmation. |
| 4 | **About FitCalorie** | App name, description, version from `PackageInfo`. |
| 5 | **Sign Out** | `CupertinoAlertDialog` confirmation → `supabaseProvider.signOut()`. |

---

## Complete Profile Page (Onboarding)

`features/onboarding/complete_profile_page.dart` — shown once after first sign-up (or whenever `isProfileComplete == false`, i.e. any of `birthdate`, `gender`, `height`, `weight` is missing).

**Step 1 (required):** Birthdate (date picker) · Gender (icon selector: Male / Female / Other) · Height (number field)

**Step 2 (required):** Weight · Waistline (waistline optional)

**Step 3 (optional):** Activity Level (tap-to-select list)

- Accepts an optional `initialProfile` parameter — if provided, all existing fields are pre-populated in `initState` so users only need to fill the missing fields
- Animated progress dots (pill-style) at the top — 3 dots total
- **No skip buttons** — "Continue" advances Step 1 → Step 2 (after validation) and Step 2 → Step 3; Step 3 has a single "Save & Start Tracking" button
- On complete: `AppShell` navigates directly to `MainScaffold` (no check-in step)
- Widgets extracted into `features/onboarding/widgets/`: `ProfileProgressDots`, `ProfileFieldLabel`, `ProfileInputField`, `ProfileGenderSelector`, `ProfileActivitySelector`

---

## Communication

- **Reply to the user in Chinese (Hong Kong / Cantonese)**, with English technical terms kept as-is (e.g. `widget`, `null safety`, `RLS`).
- All code, comments, and documentation must be written in **English**.
