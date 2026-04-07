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

## UI & Visual Style

- **Colours:** Never hardcode. Use `AppTheme.primary` (green), `AppTheme.accent` (orange), `AppTheme.background`, `AppTheme.destructive`.
- **Spacing (8-Point Grid):** Strictly use multiples of 8 (8, 16, 24, 32, 48, 64) with 4/12 for fine-tuning. Never use odd values (5, 7) or 3/6.
- **Border Radius:** Only use 4, 8, 12, 16, or 24.
- **Components:**
  - Confirmation dialogs: `CupertinoAlertDialog` (destructive actions use `isDestructiveAction: true`).
  - Date pickers: `CupertinoDatePicker` inside `showCupertinoModalPopup`. Never use Material date pickers.
- **Image handling before upload:** Limit longest edge to 1280px, compress via `image` package to JPEG <1.5MB base64.
