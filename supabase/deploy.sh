#!/usr/bin/env bash
# End-to-end Supabase setup for Wild Go: link, push schema, set secrets, deploy.
#
# Prerequisites:
#   - Dependencies installed with `npm install`
#   - Supabase CLI authenticated with `npm exec -- supabase login`
#   - A Supabase project ref (Project Settings -> General -> Reference ID)
#
# Usage:
#   SUPABASE_PROJECT_REF=abcd1234 \
#   OPENAI_API_KEY=sk-... \
#   supabase/deploy.sh
#
# Optional:
#   OPENAI_VISION_MODEL=gpt-4.1-mini   (default)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if command -v supabase >/dev/null 2>&1; then
  SUPABASE_CLI="$(command -v supabase)"
elif [[ -x "$PWD/node_modules/.bin/supabase" ]]; then
  SUPABASE_CLI="$PWD/node_modules/.bin/supabase"
else
  echo "Project Supabase CLI not found. Run npm install first." >&2
  exit 1
fi

: "${SUPABASE_PROJECT_REF:?Set SUPABASE_PROJECT_REF to your project reference id}"
: "${OPENAI_API_KEY:?Set OPENAI_API_KEY}"
OPENAI_VISION_MODEL="${OPENAI_VISION_MODEL:-gpt-4.1-mini}"

echo "==> Linking project $SUPABASE_PROJECT_REF"
"$SUPABASE_CLI" link --project-ref "$SUPABASE_PROJECT_REF"

echo "==> Pushing database schema (migrations)"
"$SUPABASE_CLI" db push

echo "==> Setting Edge Function secrets"
"$SUPABASE_CLI" secrets set \
  "OPENAI_API_KEY=$OPENAI_API_KEY" \
  "OPENAI_VISION_MODEL=$OPENAI_VISION_MODEL"

echo "==> Deploying identify-species function"
"$SUPABASE_CLI" functions deploy identify-species

cat <<EOF

Done. Next:
  1. Put SUPABASE_URL + SUPABASE_ANON_KEY into ios/debug.xcconfig
     (copy from ios/debug.xcconfig.example).
  2. Rebuild the app: npm run ios:build
  3. Capture or import a photo to exercise the live cloud path.
EOF
