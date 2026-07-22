# Wild Go Supabase

This folder is the backend target for the native SwiftUI MVP.

## Pieces

- `migrations/20260705220500_initial_wild_go.sql` creates the `observations` Postgres table, indexes, authenticated Row Level Security policies, and the private `observations` Storage bucket.
- `functions/identify-species` is a Deno Edge Function that calls the OpenAI Responses API for cloud species recognition, verifies any signed-in user JWT through Supabase Auth, uploads the observation image to Storage with the service role key, writes the resulting card metadata to Postgres, and removes newly uploaded images when a downstream step fails.
- `functions/identify-species/species-result.ts` normalizes generous model output into card-safe rarity, finish, star, confidence, note, and alternative-match values before the result is returned or persisted.
- `functions/identify-species/request-utils.ts` keeps the request-side contract testable: data URL/base64 decoding, private Storage path construction, path-segment sanitization, MIME suffix mapping, and Supabase Auth bearer-token verification.

## Required secrets

Set these in Supabase before deploying the function. `OPENAI_API_KEY` is required for normal cloud recognition; without it the Edge Function returns a configuration error instead of inventing an identification.

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set OPENAI_VISION_MODEL=gpt-4.1-mini
```

Do not manually create secrets whose names start with `SUPABASE_`. Supabase
reserves that prefix and automatically injects `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` into hosted Edge Functions.
See the official [Edge Function environment variable documentation](https://supabase.com/docs/guides/functions/secrets).

For local demos only, you can opt into the fixed sample card fallback:

```bash
supabase secrets set ALLOW_DEMO_IDENTIFICATION=true
```

Do not enable `ALLOW_DEMO_IDENTIFICATION` in production. It records `source = 'fallback'` and exists only so the UI can be demonstrated before cloud API secrets are available.

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `Info.plist` build settings. Add those values in an `.xcconfig` or Xcode build settings before testing against a real Supabase project. The native app sends JPEG image data, a stable local `clientId`, a per-observation UUID, optional location, and capture time to the Edge Function.

The Edge Function uses `SUPABASE_SERVICE_ROLE_KEY` for controlled Storage and anonymous writes. Anonymous images are placed in `observations/devices/{clientId}/...`; when the iOS app sends a signed-in user JWT, the function first verifies that token through Supabase Auth's `/auth/v1/user` endpoint, then uses the app's validated observation UUID for the private `observations/{userId}/{observationId}.jpg` object and matching Postgres row. Authenticated Postgres reads and writes retain that verified user JWT and the anon key so Row Level Security still enforces record ownership; they do not bypass RLS with the service role. This keeps SwiftData, Storage, and Postgres identity aligned and makes signed-in retries idempotent. Before overwriting a signed-in object, the function checks whether its row already exists. OpenAI transport/output failures and Postgres write failures delete only images created by the current uncommitted attempt; an existing card image is preserved on a failed retry. Cleanup uses the Storage API, so the file and Storage metadata are removed together. The original recognition or persistence error remains the response if cleanup itself fails, while cleanup failure is logged for operations. The iOS app refreshes stale Supabase access tokens before signed-in recognition and sync calls. Signed-in collection sync also migrates device-path observations, uploads remaining local-only JPEGs with the user's JWT, reads the user's Postgres rows, and caches authenticated private Storage objects back into the local SwiftData binder.

## Deploy

The repo pins Supabase CLI `2.109.1` as a development dependency. Install once
with `npm install`; all commands below then use the project-local CLI rather
than depending on a machine-global version.

For the usual project setup, export the required values and run the helper:

```bash
SUPABASE_PROJECT_REF=abcd1234 \
OPENAI_API_KEY=sk-... \
npm run supabase:deploy
```

The script links the project, applies migrations, sets Edge Function secrets, and deploys `identify-species`.

Manual deploy:

```bash
npm exec -- supabase db push
npm exec -- supabase functions deploy identify-species
```

For local function serving, copy `functions/identify-species/.env.example` to an ignored `.env.local` and fill in local values.

## Test

Run the function-level contract tests without live Supabase or OpenAI secrets:

```bash
npm run supabase:verify
```

This runs the Deno contract suite, type-checks the deployed function entrypoint,
checks the pinned CLI, and validates the deploy script. The tests cover
model-output normalization, request utilities, explicit demo-mode disclosure,
fail-closed cloud configuration, and the complete request handler with injected
network responses. Handler tests prove the successful upload/OpenAI/Postgres
sequence, Storage cleanup after OpenAI or Postgres failure, and preservation of
an existing signed-in image with RLS-authenticated preflight reads.

With Docker running, use the pinned CLI to start and reset the complete local
Supabase stack:

```bash
npm run supabase:start
npm run supabase:reset
npm run supabase:stop
```
