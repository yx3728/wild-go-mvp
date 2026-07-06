#!/usr/bin/env bash
# End-to-end Supabase setup for Wild Go: link, push schema, set secrets, deploy.
#
# Prerequisites:
#   - Supabase CLI installed and logged in: `supabase login`
#   - A Supabase project ref (Project Settings -> General -> Reference ID)
#
# Usage:
#   SUPABASE_PROJECT_REF=abcd1234 \
#   OPENAI_API_KEY=sk-... \
#   SUPABASE_SERVICE_ROLE_KEY=... \
#   SUPABASE_ANON_KEY=... \
#   supabase/deploy.sh
#
# Optional:
#   OPENAI_VISION_MODEL=gpt-4.1-mini   (default)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI not found. Install: https://supabase.com/docs/guides/cli" >&2
  exit 1
fi

: "${SUPABASE_PROJECT_REF:?Set SUPABASE_PROJECT_REF to your project reference id}"
: "${OPENAI_API_KEY:?Set OPENAI_API_KEY}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY}"
OPENAI_VISION_MODEL="${OPENAI_VISION_MODEL:-gpt-4.1-mini}"

echo "==> Linking project $SUPABASE_PROJECT_REF"
supabase link --project-ref "$SUPABASE_PROJECT_REF"

echo "==> Pushing database schema (migrations)"
supabase db push

echo "==> Setting Edge Function secrets"
supabase secrets set \
  "OPENAI_API_KEY=$OPENAI_API_KEY" \
  "OPENAI_VISION_MODEL=$OPENAI_VISION_MODEL" \
  "SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY" \
  "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

echo "==> Deploying identify-species function"
supabase functions deploy identify-species

cat <<EOF

Done. Next:
  1. Put SUPABASE_URL + SUPABASE_ANON_KEY into ios/debug.xcconfig
     (copy from ios/debug.xcconfig.example).
  2. Rebuild the app: npm run ios:build
  3. Capture or import a photo to exercise the live cloud path.
EOF
