# FitCalorie — Project Guidelines

## Overview

**FitCalorie** is an AI-powered food calorie tracking app designed for Hong Kong users.

## Highest Rules

- **Language:** Reply to the user in **Chinese (Hong Kong / Cantonese)**. Keep technical terms in English. All generated code and comments must be in English.
- **Verification:** Always run `dart analyze` after editing `.dart` files and ensure zero errors.
- **Testing After Edits:** After any agent edits to the app code, also add or update corresponding unit tests (in `test/`) and integration tests (in `integration_test/`) where applicable. Run `flutter test` (and integration tests if set up) to verify and ensure zero failures. If integration tests cannot be added due to technical constraints, note the reason in code comments.
- **Documentation Updates:** Always check and propose updates to `README.md` and instruction files whenever making major changes or adding new features.

## Copilot Collaboration Style

- **Critical First, Not Blind Implementation:** Never accept or implement a request blindly. Evaluate technical, UX, performance, and maintainability impact first.
- **Raise Concerns Early:** If an idea feels risky, suboptimal, not production-ready, or inconsistent with project rules, clearly state concerns and why.
- **Propose Better Alternatives:** When a cleaner solution exists, suggest it with trade-offs and a practical implementation direction.
- **Discuss Before Final Implementation:** Clarify requirements and confirm the chosen direction with the user before implementing major or ambiguous changes.
- **Feedback Tone:** Keep normal replies in Chinese (Hong Kong / Cantonese), and when discussing UX/product feedback you may use brief casual Hong Kong English phrases naturally.
- **Preferred Response Pattern:** (1) concerns/doubts, (2) improved suggestion, (3) ask for confirmation.

## Product UI/UX Non-Negotiables

- **Architecture:** Keep feature-first structure (`lib/features/`, `lib/core/`, `lib/shared/`).
- **Copy Language:** All in-app UI text must be English only.
- **Design System:** Use `AppTheme` and `AppSpacing`; avoid hardcoded colours and spacing values.
- **Brand Colours:** Primary green `#10B981`, accent orange `#FF6B35`.
- **Visual Direction:** Light mode only, Material 3, radius `16` as the default for cards and primary buttons.
- **Dialogs:** Use `CupertinoAlertDialog` for all user confirmation/decision dialogs.
- **Code Style:** Prefer `const` constructors, trailing commas, and English comments.
- **Charts:** Use `fl_chart` with weekday labels `S/M/T/W/T/F/S`.
- **AI Flow:** Keep meal analysis aligned with the Supabase Edge Function `analyze-meal` structured JSON contract.
- **Core Flow:** Preserve onboarding and daily check-in flow expectations.
- **Insight Tone:** User-facing insights should sound like casual HK English (friendly and practical).

## Testing Conventions

- **Feature-first test layout:** Keep tests grouped by type and feature under `test/unit/`, `test/widget/`, and `integration_test/`.
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
