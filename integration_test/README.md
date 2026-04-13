# FitCalorie Integration Test Guide

This folder contains integration tests for cross-screen user flows and backend-connected scenarios.

## Current Suites

- `app_test.dart`: Critical flow (auth, onboarding, check-in, add food, analysis/log navigation).
- `add_food_image_path_flow_test.dart`: Add-food image path flow coverage.
- `analysis_food_flow_test.dart`: Real backend analysis flow with Supabase + edge function.
- `auto_login_setup_flow_test.dart`: Login/setup flow coverage.

## Test Assets

- `images/`: Fixture photos used by integration tests.

## Recommended Commands

Run these from the repository root:

```bash
flutter test integration_test/app_test.dart
flutter test integration_test/add_food_image_path_flow_test.dart
flutter test integration_test/auto_login_setup_flow_test.dart
```

For real backend analysis flow:

```bash
make test-analysis-flow EMAIL="<test-email>" PASSWORD="<test-password>"
```

Optional overrides:

- `IOS_SIM`: iOS simulator name (default from `Makefile`).
- `TEST_IMAGE_PATH`: Image path for analysis flow (default `integration_test/images/3_egg_tarts.jpg`).

## Conventions

- Keep flows deterministic whenever possible.
- Use fake providers for non-backend integration tests.
- Reserve real backend tests for scenarios that must validate Supabase/edge contracts.

## Related Docs

- Root project guide: `../README.md`
- Unit/widget tests: `../test/README.md`
