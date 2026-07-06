# Wild Go MVP Handoff

## Project Summary

Wild Go is a mobile-first prototype for a real-world urban nature collection app. Users photograph nearby plants and animals, receive AI-assisted identification, and collect each discovery as an original rarity card built from their own photos.

The MVP combines three confirmed product directions:

1. **Foil Reveal Capture**: the post-capture moment turns a finding into a six-star holographic card.
2. **Urban Card Binder**: every collected organism lives in a card binder with visible rarity tiers.
3. **Card Stack Social**: friend activity and sharing use physical-feeling card stacks instead of a generic social feed.

## Current Prototype

Local app path:

```text
wild-go-mvp/
```

Local dev URL while running:

```text
http://127.0.0.1:5173
```

Core files:

```text
src/App.jsx
src/styles.css
public/assets/
docs/card-visuals/
ios/App/App.xcodeproj
supabase/
design-qa.md
qa-shots/
```

## Card Visual References

These three source visuals are the canonical card-system direction for the MVP:

| Visual | File | Role |
| --- | --- | --- |
| Binder rarity grid | [`docs/card-visuals/binder-rarity-grid.png`](./docs/card-visuals/binder-rarity-grid.png) | Collection view showing the full binder, card scale hierarchy, and rarity guide. |
| Capture holo unlock | [`docs/card-visuals/capture-holo-unlock.png`](./docs/card-visuals/capture-holo-unlock.png) | Post-capture reveal for the most exciting moment: a six-star holographic card unlock. |
| Friends showcase stack | [`docs/card-visuals/friends-showcase-stack.png`](./docs/card-visuals/friends-showcase-stack.png) | Social/share direction using draggable physical card stacks instead of a generic feed. |

![Binder rarity grid](./docs/card-visuals/binder-rarity-grid.png)

![Capture holo unlock](./docs/card-visuals/capture-holo-unlock.png)

![Friends showcase stack](./docs/card-visuals/friends-showcase-stack.png)

Card visual rules from these references:

- Every organism photo becomes a collectible card, not a plain observation tile.
- Rarity must be visible directly from the card face through star count, border material, label, finish, and accent color.
- Six stars is the maximum rarity and should read as a holographic/foil chase card.
- Lower rarities should still feel collectible: 1-star matte, 2-star colored, 3-star metallic, 4-star iridescent, 5-star foil, 6-star holo foil.
- Cards should support physical interactions: tilt to shimmer, press for depth, flip for details, drag/showcase for social use.
- Rarity is app discovery difficulty, not conservation status.

Implementation note: card physics and material should use existing MIT-licensed GitHub packages rather than custom one-off math:

- [`react-parallax-tilt`](https://github.com/mkosir/react-parallax-tilt) handles pointer/touch tilt, perspective, glare, and gyroscope support.
- [`Sticker`](https://github.com/bpisano/Sticker) is wired into the native SwiftUI target as an SPM dependency for Pokemon-style Metal foil shaders and motion-driven shimmer. Native foil art now uses Sticker-driven border, card-surface, and constrained spectral photo layers with the package README's example shader parameters instead of hand-written gradient art. On iOS 18+, Sticker shaders are precompiled on launch.

## What Is Implemented

- Mobile-first Vite + React prototype retained for design comparison.
- Native SwiftUI iOS shell that builds and runs in the iPhone simulator.
- SwiftData local persistence, AVFoundation camera preview and still capture, PhotosUI import, MapKit location views, and CoreLocation capture metadata.
- Captured/imported JPEGs are normalized, saved under the app support `ObservationPhotos` folder, and referenced by SwiftData cards so newly identified observations use the user's photo instead of a static demo asset.
- Cloud-first species recognition through the Supabase Edge Function, with private Storage upload and Postgres observation persistence.
- Signed-in collection sync now uploads local-only SwiftData card photos to private Storage when the app still has the local JPEG, pushes card metadata to Postgres, pulls the user's cloud observations back into SwiftData, and caches private Storage images locally when the authenticated download succeeds.
- Vision/Core ML local recognition is wired through `VNCoreMLRequest`; adding a compiled `WildGoSpeciesClassifier.mlmodelc` to the app bundle enables local fallback/offline classification.
- Restored iOS AppIcon asset catalog and LaunchScreen storyboard build resources.
- Six-star holographic unlock card for the capture result.
- Creature cards using bitmap nature photo assets, including a target-matched rock pigeon card crop.
- Visible rarity system from 1 to 6 stars.
- Rarity is treated as app discovery difficulty, not conservation status.
- Distinct card finishes:
  - 1 star: common matte
  - 2 stars: uncommon colored
  - 3 stars: rare metallic
  - 4 stars: seasonal iridescent
  - 5 stars: local special foil
  - 6 stars: city legend holo foil
- Card interactions:
  - pointer/touch tilt shimmer
  - opt-in device-orientation foil movement on supported phones
  - press depth
  - flip to card back with field notes, habitat, privacy, and wildlife guidance
  - add-to-binder state
  - simulator-safe add-to-binder fallback when AVFoundation has no active photo video connection
  - rarity filtering
  - social showcase toggle with a visible drop/showcase slot and a flippable showcase card back
- Bottom navigation:
  - Explore
  - Map
  - Capture
  - Cards
  - Profile
- Wildlife/privacy copy:
  - approximate location
  - location softened
  - rarity is discovery difficulty

## Validation

Commands run:

```bash
npm install
npm run build
deno check supabase/functions/identify-species/index.ts
plutil -lint ios/App/App/Info.plist
npm run ios:build
xcrun simctl install booted ios/App/build-native/Build/Products/Debug-iphonesimulator/App.app
xcrun simctl launch booted com.wildgo.mvp --wildgo-tab binder
xcrun simctl launch booted com.wildgo.mvp --wildgo-tab capture
```

QA artifacts:

```text
design-qa.md
public/assets/wild-go-combo-target.png
qa-shots/ios-simulator-final-compact.png
qa-shots/ios-simulator-final-material.png
qa-shots/interaction-binder-smoke.png
qa-shots/interaction-capture-smoke.png
qa-shots/interaction-profile-smoke.png
qa-shots/material-capture.png
qa-shots/material-cards.png
qa-shots/material-friends-stack.png
qa-shots/swiftui-native-binder-sticker-foil-v3.png
qa-shots/swiftui-native-binder-v7.png
qa-shots/swiftui-native-binder-grid-layout-final.png
qa-shots/swiftui-native-binder-list-interaction-v1.png
qa-shots/swiftui-native-binder-sort-rarity-v1.png
qa-shots/swiftui-native-capture-sticker-foil-v3.png
qa-shots/swiftui-native-capture-sticker-example-params-v1.png
qa-shots/swiftui-native-capture-holo-texture-v6.png
qa-shots/swiftui-native-capture-layout-final.png
qa-shots/swiftui-native-capture-back-layout-final.png
qa-shots/swiftui-native-capture-photo-pipeline-v1.png
qa-shots/swiftui-native-capture-card-back-v1.png
qa-shots/swiftui-native-capture-depth-card-back-v1.png
qa-shots/swiftui-native-capture-flip-back-v2.png
qa-shots/swiftui-native-capture-depth-button-v2.png
qa-shots/swiftui-native-capture-add-to-binder-v2.png
qa-shots/swiftui-native-capture-share-sheet-v2.png
qa-shots/swiftui-native-capture-tilt-button-v2.png
qa-shots/swiftui-native-capture-v2.png
qa-shots/swiftui-native-friends-sticker-foil-v3.png
qa-shots/swiftui-native-friends-profile-v13.png
qa-shots/swiftui-native-friends-profile-v16.png
qa-shots/swiftui-native-profile-interactions-v2.png
qa-shots/swiftui-native-profile-showcase-back-dropped-v1.png
qa-shots/tuned-capture.png
qa-shots/tuned-cards.png
qa-shots/tuned-map.png
```

QA result:

```text
final result: passed
```

Browser checks covered:

- 390 x 844 mobile viewport.
- No horizontal overflow.
- All creature images load.
- Bottom navigation renders all five destinations.
- Flip interaction reveals card back content.
- Capture Press & Hold changes card depth, and Capture Flip swaps the six-star card to a field-notes back.
- Capture unlock layout now keeps the hero card, interaction controls, Add to Binder, and Share Card fully visible on the iPhone 17 Pro simulator.
- Capture Share Card opens the native share sheet; Flip and Press & Hold were re-verified after the responsive layout pass.
- Capture foil art was reworked onto Sticker's GitHub Metal shader package with layered border/photo/surface passes and then reset to the package README's example shader parameters; `swiftui-native-capture-sticker-example-params-v1.png` is the current reference QA screenshot.
- Real-coordinate automation verified Capture Tilt, Press & Hold, Flip, Add to Binder, and Share Card. Add to Binder now stays in-app and falls back to the demo image on Simulator instead of crashing when AVFoundation has no active video connection.
- Friends Flip swaps the showcase card to its back, and Drag/Add to Showcase changes the visible showcase slot state.
- Friends/Profile `v16` tightens the reference-style action rail so long labels fit, restores a visible trade/friends icon with a supported SF Symbol, and reduces the back-card typography so the small cards read as a physical stack instead of cropped posters.
- Real-coordinate automation verified Friends Drag to showcase, Flip, Trade Later, and Compare after the `v16` visual pass.
- Binder List view now switches to a real list board, and Grid view returns to the reference-style binder grid.
- Binder sorting changes both the menu label and the visible card ordering; Rarity sorting was verified in Simulator.
- Binder Tips opens the native alert, and toast feedback renders below the Dynamic Island safe area.
- Add to Binder updates button state.
- 5-6 rarity filter returns the five-star and six-star cards.
- Map, binder, and capture screens render without visual overlap.
- Friends showcase stack keeps intentional card overflow without colliding with the bottom navigation.
- iOS simulator launches full screen with restored app icon and launch storyboard resources compiled by Xcode.

## Run Locally

```bash
cd wild-go-mvp
npm install
npm run dev -- --port 5173
```

Then open:

```text
http://127.0.0.1:5173
```

## Run iOS

```bash
cd wild-go-mvp
npm install
npm run ios:build
xcrun simctl install booted ios/App/build-native/Build/Products/Debug-iphonesimulator/App.app
xcrun simctl launch booted com.wildgo.mvp
```

Use `npm run ios:open` to continue in Xcode. Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `ios/debug.xcconfig` or Xcode build settings before testing against a live Supabase project.

For visual QA, pass a tab override such as `xcrun simctl launch booted com.wildgo.mvp --wildgo-tab capture`, `--wildgo-tab binder`, or `--wildgo-tab profile` to open native target screens directly.

## Product Notes

The card system is intentionally original. It borrows the general emotional appeal of collectible trading cards but avoids copying Pokemon card layouts, marks, type symbols, or franchise-specific visual language.

The strongest MVP loop is:

```text
Capture -> AI likely match -> six-star/rarity reveal -> add to binder -> share/showcase
```

## Recommended Next Steps

1. Configure live Supabase project values and secrets for end-to-end cloud recognition/storage.
   - Copy `ios/debug.xcconfig.example` to `ios/debug.xcconfig` and add your project URL + anon key.
   - Set `OPENAI_API_KEY`; the Edge Function now fails fast without it unless `ALLOW_DEMO_IDENTIFICATION=true` is explicitly enabled for local demos.
2. ~~Add Supabase Auth screens and user-account syncing for card collections.~~ **Done:** Profile avatar opens the auth sheet; signed-in users upload local card photos to private Storage when available, push binder metadata to Postgres, and pull cloud observations back into SwiftData.
3. Test AVFoundation still-photo capture on physical devices and tune simulator fallbacks.
4. Train/export `WildGoSpeciesClassifier.mlmodelc` and add it to the Xcode target to activate local/offline classification.
5. ~~Expand card backs with habitat, seasonality, safety guidance, and confidence alternatives.~~ **Done:** `SpeciesFieldGuide` powers capture card backs and cloud responses can return `alternativeMatches`.
6. ~~Add share-card export as an image.~~ **Done:** Share Card now exports a rendered card image plus text through the native share sheet.
7. ~~Add privacy rules for sensitive species and exact locations.~~ **Done:** `PrivacyLocationPolicy` softens map pins and locality labels for sensitive/high-rarity finds.

## Known Limitations

- The SwiftUI app includes local SwiftData persistence and a Supabase Edge Function path for Storage/Postgres persistence, but live cloud recognition requires project secrets. Missing `OPENAI_API_KEY` is now a hard configuration error unless local demo fallback is explicitly enabled.
- Authentication is implemented with email/password against Supabase Auth. Magic-link confirmation may still be required depending on project auth settings.
- Collection sync now has a bidirectional Postgres/SwiftData merge plus authenticated local-photo Storage upload, but conflict handling is intentionally simple: local rows are matched by UUID or uploaded Storage path, and remote-only rows use generated placeholder art when private Storage image download is unavailable.
- Vision + Core ML local recognition is implemented as a runtime path, but still needs a bundled compiled model before it can classify offline.
