run:
	dart run build_runner build --delete-conflicting-outputs && flutter run

build:
	dart run build_runner build --delete-conflicting-outputs && flutter build ios

gen:
	dart run build_runner build --delete-conflicting-outputs

# ── Supabase Edge Functions ──────────────────────────
# Deploy all edge functions at once
deploy-functions:
	supabase functions deploy

# Deploy single function (usage: make deploy-fn NAME=analyze-meal)
deploy-fn:
	supabase functions deploy $(NAME)

# Set secrets for edge functions
set-secrets:
	supabase secrets set GEMINI_API_KEY=$(GEMINI_API_KEY)

# Serve functions locally for testing
serve-functions:
	supabase functions serve --env-file supabase/.env.local
