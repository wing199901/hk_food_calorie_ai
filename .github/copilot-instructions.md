# FitCalorie — Project Guidelines

## Overview

**FitCalorie** is an AI-powered food calorie tracking app designed for Hong Kong users.

## Highest Rules

- **Language:** Reply to the user in **Chinese (Hong Kong / Cantonese)**. Keep technical terms in English. All generated code and comments must be in English.
- **Verification:** Always run `dart analyze` after editing `.dart` files and ensure zero errors.
- **Testing After Edits:** After any agent edits to the app code, also add or update corresponding unit tests (in `test/`) and e2e (in `test/e2e`) where applicable. Run `flutter test` (and integration tests if set up) to verify and ensure zero failures. If e2e tests cannot be added due to technical constraints, note the reason in code comments.
- **Documentation Updates:** Always check and propose updates to `README.md` and instruction files whenever making major changes or adding new features.

## Testing Conventions

- **Feature-first test layout:** Keep tests grouped by type and feature under `test/unit/`, `test/widget/`, and `test/e2e/`.
- **Deterministic UI flow testing:** Prefer provider overrides with fake services for widget/e2e tests to avoid external dependencies.
- **Photo analysis flow tests:** Use deterministic test controls (for example, test-only triggers in `AddFoodPage`) for predictable valid/invalid/network error scenarios.

## Code Readability & Commenting

- **Structural Comments:** Use clear section markers (e.g., `// --- Header Section ---`) to distinctively separate different areas of the code.
- **Explain the "Why":** Add inline comments explaining non-trivial logic, calculations, and state changes. Do not just translate the code syntax into English—explain the underlying intention.
- **Keep it Readable:** Break dense code blocks apart with vertical whitespace (blank lines) paired with a brief explanatory comment.
- **Documentation Comments:** When creating new shared components or utilities, use documentation comments (like `///` in Dart) to explain their purpose.

## Architecture & Database Security

- **Database:** See `README.md` for schemas (`user_profiles`, `body_metrics`, `meal_records`, `quick_add_items`).
- **Source of Truth:** `supabase/schema.sql`.
- **RLS:** All tables must enforce Row Level Security. All policies use `auth.uid() = user_id`. Never bypass RLS on the client side.
