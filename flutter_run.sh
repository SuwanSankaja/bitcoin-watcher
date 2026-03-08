#!/bin/bash
# Flutter run with secrets injected from Doppler.
#
# Usage:
#   ./flutter_run.sh                   → flutter run (debug, default device)
#   ./flutter_run.sh build apk         → flutter build apk
#   ./flutter_run.sh run -d chrome     → flutter run on chrome
#
# Token is read from .doppler-token file (gitignored),
# or from DOPPLER_SERVICE_TOKEN env var.

set -e

DOPPLER_TOKEN_FILE=".doppler-token"
ENV_FILE=".env"
TEMP_ENV_FILE="/tmp/.bitcoin_watcher_flutter.env"

# Commands that support --dart-define-from-file
DART_DEFINE_COMMANDS=("run" "build" "test" "drive")

# ── Args ──────────────────────────────────────────────────────────────────────
FLUTTER_ARGS=("${@:-run}")
FIRST_ARG="${FLUTTER_ARGS[0]}"

# ── Check if this command supports --dart-define-from-file ────────────────────
NEEDS_DEFINES=false
for cmd in "${DART_DEFINE_COMMANDS[@]}"; do
  if [[ "$FIRST_ARG" == "$cmd" ]]; then
    NEEDS_DEFINES=true
    break
  fi
done

if [ "$NEEDS_DEFINES" = false ]; then
  echo "🚀  Running: flutter ${FLUTTER_ARGS[*]}"
  flutter "${FLUTTER_ARGS[@]}"
  exit 0
fi

# ── Load token (priority: env var → .env → .doppler-token) ───────────────────
if [ -z "$DOPPLER_SERVICE_TOKEN" ]; then
  if [ -f "$ENV_FILE" ]; then
    DOPPLER_SERVICE_TOKEN=$(grep -E "^DOPPLER_SERVICE_TOKEN=" "$ENV_FILE" | cut -d '=' -f2- | tr -d '[:space:]"'"'"')
  fi
fi
if [ -z "$DOPPLER_SERVICE_TOKEN" ] && [ -f "$DOPPLER_TOKEN_FILE" ]; then
  DOPPLER_SERVICE_TOKEN=$(cat "$DOPPLER_TOKEN_FILE" | tr -d '[:space:]')
fi
if [ -z "$DOPPLER_SERVICE_TOKEN" ]; then
  echo "❌  No Doppler token found. Add DOPPLER_SERVICE_TOKEN to .env"
  exit 1
fi

# ── Fetch secrets from Doppler ────────────────────────────────────────────────
echo "🔑  Fetching secrets from Doppler..."
HTTP_STATUS=$(curl -sf \
  --request GET \
  --url "https://api.doppler.com/v3/configs/config/secrets/download?format=env" \
  --header "authorization: Bearer $DOPPLER_SERVICE_TOKEN" \
  --output "$TEMP_ENV_FILE" \
  --write-out "%{http_code}" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" != "200" ] && [ ! -s "$TEMP_ENV_FILE" ]; then
  echo "❌  Failed to fetch secrets from Doppler (HTTP $HTTP_STATUS)."
  rm -f "$TEMP_ENV_FILE"
  exit 1
fi

echo "✅  Secrets loaded from Doppler (project: bitcoin-watcher / prd)."

# ── Run flutter with dart-defines injected ─────────────────────────────────
echo "🚀  Running: flutter ${FLUTTER_ARGS[*]}"
flutter "${FLUTTER_ARGS[@]}" --dart-define-from-file="$TEMP_ENV_FILE"

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f "$TEMP_ENV_FILE"
