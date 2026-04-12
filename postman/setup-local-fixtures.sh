#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${POSTMAN_FIXTURE_IMAGES_DIR:-$ROOT_DIR/integration_test/images}"
USER_ID="${POSTMAN_FIXTURE_USER_ID:-00000000-0000-0000-0000-000000000001}"
BUCKET="${POSTMAN_FIXTURE_BUCKET:-meal-images}"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Error: supabase CLI not found in PATH." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl not found in PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 not found in PATH." >&2
  exit 1
fi

STATUS_JSON="$(cd "$ROOT_DIR" && supabase status -o json | sed -n '/^{/,$p')"

STATUS_VALUES="$(printf '%s' "$STATUS_JSON" | python3 -c 'import sys, json
obj = json.load(sys.stdin)
api_url = obj.get("API_URL", "")
service_role_key = obj.get("SERVICE_ROLE_KEY", "")
if not api_url or not service_role_key:
    raise SystemExit("Missing API_URL or SERVICE_ROLE_KEY from supabase status output.")
print(f"{api_url}\t{service_role_key}")
')"

IFS=$'\t' read -r API_URL SERVICE_ROLE_KEY <<< "$STATUS_VALUES"

declare -a FIXTURES=(
  "1_egg_tarts.jpg:postman/egg-tart-1.jpg"
  "3_egg_tarts.jpg:postman/egg-tart-3.jpg"
)

upload_fixture() {
  local source_name="$1"
  local object_suffix="$2"
  local source_path="$FIXTURE_DIR/$source_name"
  local object_path="${USER_ID}/${object_suffix}"
  local endpoint="${API_URL}/storage/v1/object/${BUCKET}/${object_path}"

  if [[ ! -f "$source_path" ]]; then
    echo "Error: fixture image not found: $source_path" >&2
    exit 1
  fi

  local response_file
  response_file="$(mktemp)"

  local status
  status="$(curl -sS -o "$response_file" -w "%{http_code}" \
    -X POST "$endpoint" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
    -H "apikey: ${SERVICE_ROLE_KEY}" \
    -H "x-upsert: true" \
    -H "Content-Type: image/jpeg" \
    --data-binary "@${source_path}")"

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "Error: failed uploading ${source_name} to ${BUCKET}/${object_path} (HTTP ${status})." >&2
    cat "$response_file" >&2
    rm -f "$response_file"
    exit 1
  fi

  rm -f "$response_file"
  echo "Uploaded ${source_name} -> ${BUCKET}/${object_path}"
}

for entry in "${FIXTURES[@]}"; do
  IFS=':' read -r source_name object_suffix <<< "$entry"
  upload_fixture "$source_name" "$object_suffix"
done

echo "Postman fixtures are ready for user_id=${USER_ID}."
