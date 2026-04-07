---
description: "Use when creating, editing, or debugging Supabase Edge Functions."
applyTo: "supabase/functions/**/*.ts"
---

# Supabase Edge Functions Guidelines

## Basics

- All functions accept **POST** requests with `Authorization: Bearer <jwt>`.
- Use Deno / TypeScript context.

## AI Structured Output (`analyze-meal`)

- Uses Gemini **Structured Output** (`responseMimeType` + `responseSchema`) to guarantee valid JSON.
- **Do not** manually parse or strip Markdown fences from the Gemini output; the response is already raw JSON.
- Model configs: `temperature: 0.2`, `maxOutputTokens: 2048`.

## Shared Utilities

- Place all shared code and utilities in `supabase/functions/_shared/`.
- **Errors:** Always use the shared `errorResponse` helper for returning errors to ensure consistent client-side parsing.
