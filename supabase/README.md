# Wild Go Supabase

This folder is the backend target for the native SwiftUI MVP.

## Pieces

- `migrations/20260705220500_initial_wild_go.sql` creates the `observations` Postgres table, indexes, authenticated Row Level Security policies, and the private `observations` Storage bucket.
- `functions/identify-species` is a Deno Edge Function that calls the OpenAI Responses API for cloud species recognition, verifies any signed-in user JWT through Supabase Auth, uploads the observation image to Storage with the service role key, and writes the resulting card metadata to Postgres.

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

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `Info.plist` build settings. Add those values in an `.xcconfig` or Xcode build settings before testing against a real Supabase project. The native app sends JPEG image data, a stable local `clientId`, optional location, and capture time to the Edge Function.

The Edge Function uses `SUPABASE_SERVICE_ROLE_KEY` for controlled server-side writes. Anonymous images are placed in `observations/devices/{clientId}/...`; when the iOS app sends a signed-in user JWT, the function first verifies that token through Supabase Auth's `/auth/v1/user` endpoint, then uploads to `observations/{userId}/...` and persists observations with `user_id`. The iOS app refreshes stale Supabase access tokens before signed-in recognition and sync calls. Signed-in collection sync can also upload remaining local-only JPEGs directly with the user's JWT to `observations/{userId}/{observationId}.jpg`, read the user's Postgres rows, and cache authenticated private Storage objects back into the local SwiftData binder.

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
