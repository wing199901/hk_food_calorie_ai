# FitCalorie — Project Guidelines

## Overview

**FitCalorie** is an AI-powered food calorie tracking app designed for Hong Kong users. Users photograph their meals (dim sum (點心), cha chaan teng (茶餐廳), BBQ meat (燒味), Western, Japanese/Korean, Southeast Asian, desserts, drinks, etc.) and Google Gemini automatically identifies dishes, estimates real portion sizes, calculates calories and macronutrients, and stores daily records.

---

## Tech Stack

| Layer            | Technology                                       |
| ---------------- | ------------------------------------------------ |
| Mobile App       | Flutter (Dart SDK `^3.11.0`)                     |
| Backend / DB     | Supabase (PostgreSQL + RLS)                      |
| Serverless Logic | Supabase Edge Functions (Deno / TypeScript)      |
| AI               | Google Gemini 2.5 Flash                          |
| Auth             | Supabase Auth                                    |
| Local State      | `shared_preferences` via `StorageService`        |
| Charts           | `fl_chart ^0.70.2`                               |
| Env Secrets      | `envied` + `build_runner` (generated `lib/env/`) |

---

## Database Schema

### Tables

| Table              | Primary Key            | Description                                                            |
| ------------------ | ---------------------- | ---------------------------------------------------------------------- |
| `user_profiles`    | `user_id` (uuid)       | Age, weight, height, waistline, gender, activity level, calorie target |
| `body_metrics`     | `(user_id, date)`      | Daily weight, waistline, BMI, WHtR & TEE snapshots                   |
| `meal_records`     | `id` (text)            | AI-parsed meal entries; `items` stored as JSONB array                  |
| `quick_add_items`  | `(user_id, id)` (text) | User’s custom quick-add food shortcuts with icon & macros              |
### `body_metrics` — Daily Health Snapshots

BMI, WHtR, and TEE are auto-computed and stored on every daily check-in. `StorageService.addBodyMetric()` calculates these values from the user profile before saving.

| Column      | Type          | Description                                          |
| ----------- | ------------- | ---------------------------------------------------- |
| `user_id`   | uuid (FK)     | User ID                                              |
| `date`      | date          | Date (part of composite primary key)                 |
| `weight`    | numeric(5,2)  | Body weight in kg                                    |
| `waistline` | numeric(5,2)  | Waist circumference in cm                            |
| `bmi`       | numeric(4,1)  | Body Mass Index — auto-computed from weight & height  |
| `whtr`      | numeric(3,2)  | Waist-to-Height Ratio — auto-computed                 |
| `tee`       | integer       | Total Energy Expenditure (kcal) — auto-computed       |
### `quick_add_items` — Quick Add Items

User-defined shortcut food buttons. On new user signup, a DB trigger (`seed_quick_add_items`) auto-inserts 8 default items. Users can add or delete their own quick-add items.

| Column     | Type        | Description                           |
| ---------- | ----------- | ------------------------------------- |
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

All functions accept **POST** requests with `Authorization: Bearer <jwt>`. On success they return:

```json
{ "success": true, ... }
```

On failure they return `{ "success": false, "error": "message" }` with an appropriate HTTP status code.

| Function              | Purpose                                             | Secrets          |
| --------------------- | --------------------------------------------------- | ---------------- |
| `analyze-meal`        | Gemini AI analyses photo → parses food → writes `meal_records` | `GEMINI_API_KEY` |
| `get-daily-summary`   | Fetches daily nutrition summary + AI tip                       | —                |
| `update-record`       | Updates food items and recalculates totals                     | —                |
| `delete-record`       | Soft-delete (sets `deleted_at`) or hard-delete                 | —                |
| `generate-ai-insight` | Weekly/monthly AI diet analysis report                         | `GEMINI_API_KEY` |
| `cleanup-old-records` | Cron — permanently removes soft-deleted records                | —                |

### AI Structured Output (`analyze-meal`)

`analyze-meal` uses Gemini **Structured Output** (`responseMimeType` + `responseSchema`) to guarantee valid JSON — no manual markdown fence stripping needed.

#### `systemInstruction` (behaviour / domain knowledge)

```typescript
const SYSTEM_INSTRUCTION = `You are a professional nutritionist specialising in analysing food and drink photos from any cuisine.

Core capabilities:
- All cuisines: Western (steak, burgers, pasta, salads), Japanese/Korean (ramen, sushi, fried chicken), Southeast Asian (Thai, Vietnamese), Chinese, Hong Kong-style, etc.
- Expert in Hong Kong local food: cha chaan teng (茶餐廳), dai pai dong (大排檔), dim sum (點心), street snacks, convenience store items
- Familiar with common HK dishes: siu mai (燒賣), cheung fun (腸粉), milk tea (奶茶), pork chop bun (豬扒包), pineapple bun (菠蘿包), egg tart (蛋撻), wonton noodles (雲吞麵), claypot rice (煲仔飯), etc.

Analysis rules:
- Always analyse drinks (milk tea, coffee, soft drinks, juice, beer, soup, etc.) and record volume using portion_ml
- Use portion_grams for solid food; use portion_ml for drinks — never fill both for the same item
- Estimate the actual portion shown in the photo — do not assume a standard serving size
- For uncertain items, provide the most reasonable estimate with a lower confidence score
- If the photo contains no food or is unclear, return an empty items array and populate the error field`;
```

#### `responseSchema` (JSON structure definition)

```typescript
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    items: {
      type: "ARRAY",
      description: "List of identified food/drink items. Return empty array if no food detected.",
      items: {
        type: "OBJECT",
        properties: {
          name_zh:       { type: "STRING",  description: "Food name in Traditional Chinese" },
          name_en:       { type: "STRING",  description: "English name" },
          type:          { type: "STRING",  enum: ["food", "drink"] },
          portion_size:  { type: "NUMBER",  description: "Quantity, e.g. 1, 2, 0.5" },
          portion_unit:  { type: "STRING",  description: "Unit in English" },
          portion_grams: { type: "INTEGER", nullable: true },
          portion_ml:    { type: "INTEGER", nullable: true },
          calories:      { type: "INTEGER" },
          protein:       { type: "INTEGER" },
          carbs:         { type: "INTEGER" },
          fat:           { type: "INTEGER" },
          sugar:         { type: "INTEGER" },
          confidence:    { type: "NUMBER" },
        },
        required: [
          "name_zh", "name_en", "type",
          "portion_size", "portion_unit",
          "calories", "protein", "carbs", "fat", "sugar", "confidence",
        ],
      },
    },
    total_calories: { type: "INTEGER" },
    total_protein:  { type: "INTEGER" },
    total_carbs:    { type: "INTEGER" },
    total_fat:      { type: "INTEGER" },
    error:          { type: "STRING", nullable: true },
  },
  required: ["items", "total_calories", "total_protein", "total_carbs", "total_fat"],
};
```

#### `generationConfig`

```typescript
generationConfig: {
  temperature: 0.2,
  maxOutputTokens: 2048,
  responseMimeType: "application/json",
  responseSchema: RESPONSE_SCHEMA,
}
```

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

| Token             | Hex       | Usage                                 |
| ----------------- | --------- | ------------------------------------- |
| `primary`         | `#10B981` | Brand green — buttons, header, active state          |
| `secondary`       | `#34D399` | Gradient end colour, highlights                      |
| `accent`          | `#FF6B35` | Warm orange — calorie numbers, key data, primary CTA |
| `background`      | `#F8FAFB` | Scaffold background                                  |
| `card`            | `#FFFFFF` | Card surface                                         |
| `muted`           | `#F3F4F6` | Chip background, dividers                            |
| `mutedForeground` | `#6B7280` | Secondary labels                                     |
| `foreground`      | `#1A1A1A` | Primary text                                         |
| `destructive`     | `#EF4444` | Delete, error states                                 |
| `warning`         | `#FBBF24` | Warning indicators                                   |

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
- **Health Scores (BMI / WHtR / TEE) are displayed on the Analysis Page only** — not on Settings Page
- Home Page circular progress indicator: **220×220** size, kcal font **44px**, `strokeWidth: 14`
- Analysis Page Insights use a **casual Hong Kong English tone** (e.g. "Your calories are a bit high today la~", "So consistent this week!", "Protein is your best friend 💪")

---

## Coding Conventions

- **Dart**: Follow `flutter_lints`; prefer `const` constructors + trailing commas
- **Null safety**: Use `if (x != null) x` inside collections — avoid `?` null-aware collection element syntax (not supported by the current SDK)
- **Services**: All Supabase calls must go through `SupabaseService`; never call `supabase.from()` directly inside a page widget
- **Edge functions**: Place shared utilities in `supabase/functions/_shared/`; errors must use the shared `errorResponse` helper
- **Schema**: `supabase/schema.sql` is the single source of truth — any DB changes must be reflected there, then re-applied via the DB container

---

## Communication

- **Reply to the user in Chinese (Hong Kong / Cantonese)**, with English technical terms kept as-is (e.g. `widget`, `null safety`, `RLS`).
- All code, comments, and documentation must be written in **English**.
