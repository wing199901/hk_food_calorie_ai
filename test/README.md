# FitCalorie Test Guide

This folder contains fast, deterministic test suites for app logic and UI.

## Scope

- `test/unit/`: Unit tests for services, models, and utilities.
- `test/widget/`: Widget tests for screens and reusable UI components.
- `test/helpers/`: Shared fakes, mocks, and test utilities.

Key flow coverage now includes `test/widget/screens/app_critical_flow_test.dart` to keep critical-path validation fast without platform build overhead.

For end-to-end flows, use `integration_test/` (see `integration_test/README.md`).

## Recommended Commands

Run these from the repository root:

```bash
dart analyze
flutter test test/unit
flutter test test/widget
flutter test
```

## Conventions

- Keep tests deterministic. Prefer provider overrides and fake services instead of real network calls.
- Keep assertions aligned with product copy rules (UI text in English).
- Follow feature-first organization when adding new tests.

## Related Docs

- Root project guide: `../README.md`
- Integration tests: `../integration_test/README.md`
