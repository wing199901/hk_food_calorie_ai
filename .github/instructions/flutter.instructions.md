---
description: "Use when editing or creating Flutter UI, widgets, providers, and Dart code."
applyTo: "lib/**/*.dart"
---

# Flutter & Dart Guidelines

## Architecture — Feature-First

- **Feature folder owns its page + widgets subtree.** Never import from one feature into another — share through `shared/` instead.
- **One page file per route.** Extract child widgets into `features/<name>/widgets/`.
- **`core/` has zero feature/shared dependencies.** Only Flutter SDK + `dart:` packages allowed.
- **Providers live in `shared/providers/`.** Both are `ChangeNotifierProvider` overridden in `main()`.

## State & Services

- **State Management:** All pages must extend `ConsumerStatefulWidget`; use `ref.read(storageProvider)` for one-off reads, `ref.watch(storageProvider)` to rebuild.
- **Services:** All Supabase calls must go through `SupabaseService`. Never use `supabase.from()` directly inside a UI widget.
- **Models:** `UserProfile` calculates `age` dynamically via getter. Never store or accept `age` as input. Ensure `isProfileComplete` check is valid.

## Coding Conventions

- Prefer `const` constructors + trailing commas. Follow `flutter_lints`.
- Use `if (x != null) x` inside collections — avoid `?` null-aware collection element syntax due to SDK limits.
- All user-facing UI text must be English only.

## UI & Visual Style

- **Theme Mode:** Light mode only. Prefer Material 3 components unless a Cupertino-specific pattern is required by product rules.
- **Colours:** Never hardcode. Use `AppTheme.primary` (`#10B981`), `AppTheme.accent` (`#FF6B35`), `AppTheme.background`, `AppTheme.destructive`.
- **Spacing (8-Point Grid):** Use `AppSpacing` constants first. If a new value is required, keep to 8-point increments (8, 16, 24, 32, 48, 64) with 4/12 for fine-tuning.
- **Border Radius:** Only use 4, 8, 12, 16, or 24.
- **Cards & Buttons:** Use radius `16` as the default for cards and primary buttons.
- **Charts:** Use `fl_chart` with clean weekday labels in `S/M/T/W/T/F/S` format.
- **Components:**
  - Dialogs requiring user confirmation/decision: `CupertinoAlertDialog` (destructive actions use `isDestructiveAction: true`).
  - Date pickers: `CupertinoDatePicker` inside `showCupertinoModalPopup`. Never use Material date pickers.
- **Image handling before upload:** Limit longest edge to 1280px, compress via `image` package to JPEG <1.5MB, upload to Supabase Storage, and pass `image_path` to the analysis flow.
