# FitCalorie Supabase Guide

This folder contains all Supabase assets for database schema, migrations, edge functions, and local configuration.

## Structure

- `schema.sql`: Source-of-truth schema for the app database.
- `seed.sql`: Seed data for local/testing environments.
- `migrations/`: Incremental SQL migrations.
- `functions/`: Supabase Edge Functions (Deno/TypeScript).
- `config.toml`: Local Supabase project config.
- `.env.local`: Local function runtime secrets.

## Core Rules

- Keep `schema.sql` as the canonical schema reference.
- Enforce Row Level Security (RLS) for app tables.
- Keep app and edge-function contracts in sync when changing request/response fields.

## Recommended Commands

Run these from the repository root:

```bash
# Reset local DB and provision Postman fixtures
make db-reset

# Apply a migration manually
make db-migrate FILE=supabase/migrations/<migration-file>.sql

# Serve edge functions locally
make serve-functions

# Deploy all edge functions
make deploy-functions

# Deploy one function
make deploy-fn NAME=analyze-meal

# Set secrets for functions
make set-secrets GEMINI_API_KEY="<your-gemini-key>"
```

## Related Docs

- Root project guide: `../README.md`
- Edge function details: `functions/README.md`
- Postman fixtures/API requests: `../postman/README.md`
