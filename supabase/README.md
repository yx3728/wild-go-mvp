# Wild Go Supabase

This folder is the backend target for the native SwiftUI MVP.

## Pieces

- `migrations/20260705220500_initial_wild_go.sql` creates the `observations` Postgres table, indexes, authenticated Row Level Security policies, and the private `observations` Storage bucket.
- `functions/identify-species` is a Deno Edge Function that calls the OpenAI Responses API for cloud species recognition, uploads the observation image to Storage with the service role key, and writes the resulting card metadata to Postgres.

## Required secrets

Set these in Supabase before deploying the function. `OPENAI_API_KEY` is required for normal cloud recognition; without it the Edge Function returns a configuration error instead of inventing an identification.

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set OPENAI_VISION_MODEL=gpt-4.1-mini
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
```

For local demos only, you can opt into the fixed sample card fallback:

```bash
supabase secrets set ALLOW_DEMO_IDENTIFICATION=true
```

Do not enable `ALLOW_DEMO_IDENTIFICATION` in production. It records `source = 'fallback'` and exists only so the UI can be demonstrated before cloud API secrets are available.

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `Info.plist` build settings. Add those values in an `.xcconfig` or Xcode build settings before testing against a real Supabase project. The native app sends JPEG image data, a stable local `clientId`, optional location, and capture time to the Edge Function.

The Edge Function uses `SUPABASE_SERVICE_ROLE_KEY` to place anonymous images in `observations/devices/{clientId}/...`; when the iOS app sends a signed-in user JWT, uploads move to `observations/{userId}/...` and observations persist with `user_id`. Signed-in collection sync can also upload remaining local-only JPEGs directly with the user's JWT to `observations/{userId}/{observationId}.jpg`, read the user's Postgres rows, and cache authenticated private Storage objects back into the local SwiftData binder.

## Deploy

```bash
supabase db push
supabase functions deploy identify-species
```
