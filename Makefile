run:
	dart run build_runner build --delete-conflicting-outputs && flutter run

IOS_SIM ?= iPhone 13 Pro
TEST_EMAIL ?= test@example.com
TEST_PASSWORD ?= 12345678
TEST_IMAGE_PATH ?= integration_test/images/3_egg_tarts.jpg
SUPABASE_TEST_USER_ID ?= 00000000-0000-0000-0000-000000000001

test-ios-upload-flow:
	flutter test integration_test/ios_upload_image_flow_test.dart -d "$(IOS_SIM)"

test-analysis-flow:
	flutter test integration_test/analysis_food_flow_test.dart -d "$(IOS_SIM)" \
		--dart-define=TEST_EMAIL="$(if $(EMAIL),$(EMAIL),$(TEST_EMAIL))" \
		--dart-define=TEST_PASSWORD="$(if $(PASSWORD),$(PASSWORD),$(TEST_PASSWORD))" \
		--dart-define=TEST_IMAGE_PATH="$(TEST_IMAGE_PATH)"

build:
	dart run build_runner build --delete-conflicting-outputs && flutter build ios

gen:
	dart run build_runner build --delete-conflicting-outputs

# Upload Postman fixture images to local Supabase Storage for a specific user id.
postman-fixtures:
	POSTMAN_FIXTURE_USER_ID="$(SUPABASE_TEST_USER_ID)" bash postman/setup-local-fixtures.sh

# Reset local Supabase DB, then provision Postman fixture images.
db-reset:
	@if supabase db reset; then \
		echo "Supabase db reset completed."; \
	else \
		echo "Warning: supabase db reset returned a non-zero exit code. Provisioning fixtures anyway."; \
	fi
	POSTMAN_FIXTURE_USER_ID="$(SUPABASE_TEST_USER_ID)" bash postman/setup-local-fixtures.sh

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

# Apply a migration SQL file to local Supabase DB
# Usage: make db-migrate FILE=supabase/migrations/quick_add_items.sql
db-migrate:
	/Applications/Postgres.app/Contents/Versions/latest/bin/psql postgresql://supabase_admin:postgres@127.0.0.1:54322/postgres -f $(FILE)
