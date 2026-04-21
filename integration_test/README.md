# FitCalorie Integration Test Guide

This folder contains integration tests for cross-screen user flows and backend-connected scenarios.

## Current Suites

- `analysis_food_flow_test.dart`: Real backend analysis flow with Supabase + edge function.
- `auto_login_setup_flow_test.dart`: Login/setup flow coverage.

Deterministic UI-only critical flow suites were migrated to widget tests:

- `../test/widget/screens/app_critical_flow_test.dart`
- `../test/widget/screens/add_food_page_test.dart`

## Test Assets

- `images/`: Fixture photos used by integration tests.

## Recommended Commands

Run these from the repository root:

```bash
flutter test integration_test/auto_login_setup_flow_test.dart
```

For real backend analysis flow:

```bash
make test-analysis-flow EMAIL="<test-email>" PASSWORD="<test-password>"
```

For auto login + setup flow:

```bash
make test-auto-setup-flow
```

Optional credential overrides:

```bash
make test-auto-setup-flow EMAIL="<test-email>" PASSWORD="<test-password>"
```

Optional overrides:

- `IOS_SIM`: iOS simulator name (default from `Makefile`).
- `TEST_IMAGE_PATH`: Image path for analysis flow (default `integration_test/images/3_egg_tarts.jpg`).

## Conventions

- Keep flows deterministic whenever possible.
- Prefer widget tests with fake providers for non-backend scenarios.
- Reserve integration tests for scenarios that must validate Supabase auth/storage/edge contracts end-to-end.

## Related Docs

- Root project guide: `../README.md`
- Unit/widget tests: `../test/README.md`
