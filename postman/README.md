# FitCalorie Postman Guide

This folder contains API request collections, environments, globals, and fixture setup scripts for manual edge-function testing.

## Structure

- `collections/Edge Functions/`: Request definitions for edge-function endpoints.
- `environments/Local Supabase.environment.yaml`: Local base URL and variables.
- `globals/workspace.globals.yaml`: Shared workspace-level variables.
- `setup-local-fixtures.sh`: Uploads fixture images to local Supabase Storage.

## Local Fixture Setup

Run from repository root:

```bash
make postman-fixtures
```

Or run script directly with custom options:

```bash
POSTMAN_FIXTURE_USER_ID="<user-uuid>" bash postman/setup-local-fixtures.sh
```

Optional environment variables:

- `POSTMAN_FIXTURE_USER_ID`
- `POSTMAN_FIXTURE_IMAGES_DIR`
- `POSTMAN_FIXTURE_BUCKET`

Default fixture images are read from `integration_test/images/` and uploaded to:

- `<userId>/postman/egg-tart-1.jpg`
- `<userId>/postman/egg-tart-3.jpg`

## Environment Notes

`Local Supabase.environment.yaml` includes:

- `baseUrl`: Function base URL (for local default: `http://127.0.0.1:54321/functions/v1`)
- `userId`: UUID used for fixture storage paths
- `date` and `recordId`: Helper variables for requests

## Related Docs

- Root project guide: `../README.md`
- Supabase folder guide: `../supabase/README.md`
