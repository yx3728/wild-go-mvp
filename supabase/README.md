# Wild Go Supabase

This folder is the backend target for the native SwiftUI MVP.

## Pieces

- `migrations/20260705220500_initial_wild_go.sql` creates the `observations` Postgres table, indexes, authenticated Row Level Security policies, and the private `observations` Storage bucket.
- `functions/identify-species` is a Deno Edge Function that calls the OpenAI Responses API for cloud species recognition, verifies any signed-in user JWT through Supabase Auth, uploads the observation image to Storage with the service role key, and writes the resulting card metadata to Postgres.
- `functions/identify-species/species-result.ts` normalizes generous model output into card-safe rarity, finish, star, confidence, note, and alternative-match values before the result is returned or persisted.
- `functions/identify-species/request-utils.ts` keeps the request-side contract testable: data URL/base64 decoding, private Storage path construction, path-segment sanitization, MIME suffix mapping, and Supabase Auth bearer-token verification.

## Required secrets

Set these in Supabase before deploying the function. `OPENAI_API_KEY` is required for normal cloud recognition; without it the Edge Function returns a configuration error instead of inventing an identification.

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set OPENAI_VISION_MODEL=gpt-4.1-mini
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
# Usually available automatically in hosted Supabase Edge Functions.
supabase secrets set SUPABASE_ANON_KEY=...
```

For local demos only, you can opt into the fixed sample card fallback:

```bash
supabase secrets set ALLOW_DEMO_IDENTIFICATION=true
```

Do not enable `ALLOW_DEMO_IDENTIFICATION` in production. It records `source = 'fallback'` and exists only so the UI can be demonstrated before cloud API secrets are available.

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `Info.plist` build settings. Add those values in an `.xcconfig` or Xcode build settings before testing against a real Supabase project. The native app sends JPEG image data, a stable local `clientId`, a per-observation UUID, optional location, and capture time to the Edge Function.

The Edge Function uses `SUPABASE_SERVICE_ROLE_KEY` for controlled Storage and anonymous writes. Anonymous images are placed in `observations/devices/{clientId}/...`; when the iOS app sends a signed-in user JWT, the function first verifies that token through Supabase Auth's `/auth/v1/user` endpoint, then uses the app's validated observation UUID for the private `observations/{userId}/{observationId}.jpg` object and matching Postgres row. Authenticated Postgres writes retain that verified user JWT and the anon key so Row Level Security still enforces record ownership; they do not bypass RLS with the service role. This keeps SwiftData, Storage, and Postgres identity aligned and makes signed-in retries idempotent. The function reports a failure when Storage or Postgres does not persist instead of returning a false success. The iOS app refreshes stale Supabase access tokens before signed-in recognition and sync calls. Signed-in collection sync also migrates device-path observations, uploads remaining local-only JPEGs with the user's JWT, reads the user's Postgres rows, and caches authenticated private Storage objects back into the local SwiftData binder.

## Deploy

For the usual project setup, export the required values and run the helper:

```bash
SUPABASE_PROJECT_REF=abcd1234 \
OPENAI_API_KEY=sk-... \
SUPABASE_SERVICE_ROLE_KEY=... \
SUPABASE_ANON_KEY=... \
supabase/deploy.sh
```

The script links the project, applies migrations, sets Edge Function secrets, and deploys `identify-species`.

Manual deploy:

```bash
supabase db push
supabase functions deploy identify-species
```

For local function serving, copy `functions/identify-species/.env.example` to an ignored `.env.local` and fill in local values.

## Test

Run the function-level contract tests without live Supabase or OpenAI secrets:

```bash
npm run supabase:test
```

The test suite covers model-output normalization plus request utilities, including signed-in versus anonymous Storage paths and the rule that service-role tokens are never trusted as end-user identity.
