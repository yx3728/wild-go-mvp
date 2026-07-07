# Wild Go MVP

Mobile-first prototype for Wild Go, an urban nature collection app where real organism photos become rarity-based collectible cards.

## Run

```bash
npm install
npm run dev -- --port 5173
```

Open `http://127.0.0.1:5173`.

## iOS MVP

The iOS app has been moved to a native SwiftUI shell with SwiftData, AVFoundation camera preview and still capture, MapKit, PhotosUI, and CoreLocation.
Six-star foil rendering in the native target uses the MIT-licensed [`Sticker`](https://github.com/bpisano/Sticker) Swift Package for Metal-based Pokemon-style foil shaders instead of hand-written gradient art. The capture card now layers Sticker-driven foil border, surface, and constrained spectral photo passes using the package README's example shader parameters, with iOS 18+ shader precompilation on launch.

```bash
npm run ios:build
```

With a Simulator already booted, run the native launch smoke to install the app,
open the key tabs through `--wildgo-tab`, and save verification screenshots:

```bash
npm run ios:smoke
```

To verify the main SwiftUI controls with real Simulator-window coordinate taps,
run the interaction smoke. It launches the app, taps the full bottom navigation
bar plus Capture, Cards, and Profile/Friends controls, and checks the app's
QA-only action log:

```bash
npm run ios:interactions
```

`ios:interactions` first runs a fast, Simulator-free consistency check that
confirms every `wait_for_event` assertion in `ios/qa-interactions.sh` still maps
to a `showToast` string (or tab `qaName`) in `AppDelegate.swift`, so renamed or
inverted toast copy fails immediately instead of after a full build + launch. Run
it on its own in CI with:

```bash
npm run ios:verify-events
```

To open the project in Xcode:

```bash
open ios/App/App.xcodeproj
```

The native app uses generated image assets from `ios/App/App/GeneratedAssets` for demo cards, while newly captured or imported JPEGs are saved under the app support `ObservationPhotos` folder and referenced from SwiftData cards. Supabase setup lives in `supabase/`; local app keys are read from `ios/debug.xcconfig` or Xcode build settings (`ios/debug.xcconfig.example` is provided). Captured images are sent to the `identify-species` Edge Function, which verifies signed-in user JWTs through Supabase Auth, uploads to private Supabase Storage, and writes card metadata to Postgres with the service role key. Profile → avatar opens Supabase email/password auth, refreshes short-lived Supabase access tokens with the saved refresh token before cloud requests, uploads local-only card photos to private Storage when available, pushes binder card metadata, pulls the signed-in user's Postgres observations back into SwiftData, and caches private Storage images locally when available.

Optional offline recognition is prepared in `ios/ml/`: run `ios/ml/build-model.sh <labeled_dataset>` to train a Create ML image classifier, compile it to `WildGoSpeciesClassifier.mlmodelc`, and install it into `GeneratedAssets` for the next iOS build.

To test the Supabase Edge Function's cloud-recognition result contract without
live secrets, run:

```bash
npm run supabase:test
```

To run every Simulator-free guard in one gate (goal-stack audit, QA event
consistency, concept-fidelity audit, Edge Function tests, and the web build),
use the aggregate command. It fails fast and needs no Mac Simulator, so it is
the recommended pre-commit / CI check:

```bash
npm run verify
```

## Prototype Highlights

- Six-star holographic card reveal.
- Physical-feeling card interactions in the SwiftUI shell: foil shimmer, press-depth, front/back card flip, add-to-binder fallback, share sheet, and a social showcase drop state.
- Cloud-first species recognition through a Supabase Edge Function, private Storage upload, Postgres persistence, model-output normalization, and a Vision/Core ML local-recognition path that runs when a compiled `WildGoSpeciesClassifier.mlmodelc` is bundled.
- Real capture/import photos become local collectible card images before syncing to cloud Storage.
- Rarity-based card binder with reference-style grid, real list toggle, and sorting that reorders visible cards.
- Friends activity built around card stacks, visible showcase slots, and collection milestones.
- Privacy and wildlife-safety copy baked into the card system.

See [HANDOFF.md](./HANDOFF.md) for product context, validation, and next steps.
