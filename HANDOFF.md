# Wild Go MVP Handoff

## Latest Handoff — July 13, 2026

- Working branch: `codex/native-mvp-stack-sync`
- GitHub PR: <https://github.com/yx3728/wild-go-mvp/pull/1>
- Native stack is SwiftUI + SwiftData + AVFoundation + MapKit + PhotosUI + CoreLocation. Supabase/Postgres/Storage/Edge Functions remain the cloud backend, with cloud species recognition first and Vision/Core ML fallback wired for a later trained model.
- Supabase CLI is now a project-local, exact `2.109.1` development dependency. `npm run supabase:verify` runs 18 Deno handler/contract tests, type-checks the deployed entrypoint, verifies the CLI, validates shell syntax, and enforces the hosted-secret deployment contract. The deploy helper no longer tries to set reserved `SUPABASE_*` secret names; hosted Supabase supplies those runtime values automatically, while the helper publishes only the OpenAI key and model.
- Signed-in collection sync now treats Storage upload and Postgres metadata as one ordered operation. If the local JPEG cannot upload, the card remains pending instead of being counted as synced, losing its existing device path, and retrying a metadata-only write every time Profile opens.
- Card materials now use the MIT-licensed ShaderKit package pinned exactly to `1.2.4`. One shared implementation covers all six levels: matte steel, colored alloy, crosshatched silver, iridescent pearl, inverted foil, and rainbow holo.
- Capture retains drag-responsive shader tilt, press-and-hold depth, independent front/back flip, and four-card swipe pagination. Its resting pose now uses the concept's slight clockwise `1.4` degree angle instead of the previous counter-clockwise angle, improving thumbnail geometry from `0.831` to `0.837` without changing gesture behavior.
- Capture's primary CTA now matches the concept's muted olive glass treatment instead of the previous flat neon green. The measured CTA green moves from RGB `(130, 183, 36)` to `(91, 114, 29)`, nearly matching the concept's `(95, 115, 32)` while preserving the button frame and hit target. Repeat candidate renders improve Capture composite fidelity from `0.816` to `0.818` and spatial thumbnail similarity from `0.837` to `0.843`; the regression gates now preserve both gains.
- Capture's secondary Share Card CTA now uses the concept's darker translucent fill and muted olive border instead of the former bright lime outline. Its label, icon, frame, and hit target are unchanged. Two independent renders both score composite `0.819`, thumbnail `0.843`, histogram `0.624`, and bands `0.922`; the Capture regression gates now retain the color gain.
- Binder's current grid was compacted to match the concept's vertical rhythm: the board is `468` pt tall instead of `529`, feature cards are `276`/`268` pt, and the four supporting cards are `164` pt. The six-level rarity guide is `74` pt tall, and the reference-style single-line Tilt/Binder Tips row now renders completely above the bottom navigation without dropping card names, rarity, confidence, locality, or dates.
- Binder card typography now follows the concept's compact serif hierarchy: both feature cards and all four supporting cards keep species names on one dynamically scaled line. This removes the non-reference wrapping on Eastern Gray Squirrel, Black-eyed Susan, and Monarch Butterfly without changing any card, control, or hit-target geometry. Candidate-aware concept QA measures spatial thumbnail `0.855`, histogram `0.733`, and composite `0.855` on repeat renders.
- Friends/Profile's two top-bar titles now use the concept's restrained system sans hierarchy instead of oversized rounded display type. The notification control still owns the row height, so the account, deck, activity, action-rail, and bottom-navigation geometry is unchanged. Two independent renders both improve composite fidelity from `0.814` to `0.816`, spatial thumbnail from `0.786` to `0.788`, and vertical bands from `0.930` to `0.931`.
- The Profile hero card now uses a tighter concept-matched species hierarchy inside its photo: a `19` pt serif common name, `12` pt serif italic Latin name, and smaller star row. This preserves the `228 x 338` pt card, photo window, ShaderKit border, metadata panel, and all gestures. Six-decimal QA confirms small stable gains in composite (`0.815941` to `0.815983`), thumbnail (`0.788237` to `0.788328`), and bands (`0.931069` to `0.931299`). A brighter metadata-glass trial was rejected after histogram fidelity fell to `0.740`.
- The Profile hero metadata now matches the concept's semantic hierarchy: rarity uses purple, AI confidence uses green, and captured time uses blue, while values step down from `13` pt black to `12` pt bold and supporting detail to `6.5` pt. Column widths, dividers, panel material, card geometry, and interactions are unchanged. Repeat six-decimal QA improves composite from `0.815983` to `0.816452`, thumbnail from `0.788328` to `0.788859`, and histogram from `0.747889` to `0.749045`.
- Friend Activity now matches the concept's compact type density: the section title is `16` pt, See all and both row title/subtitle pairs are `12` pt, locality/date is `10` pt, and XP is `11` pt. The heading row remains fixed at `24` pt and each activity button remains governed by its unchanged `54` pt avatar, so action geometry is preserved. Repeat QA improves composite from `0.816452` to `0.818063` and thumbnail from `0.788859` to `0.791942`; histogram moves only from `0.749045` to `0.748431`, an accepted tradeoff under the layout-first fidelity priority.
- The Profile stats row now uses the source's compact hierarchy: a `52` pt avatar in a `54` pt account button, `12` pt level/XP text, and `16`/`17` pt Cards/Places icon/value pairs. Repeat renders improve composite to `0.820452`, thumbnail to `0.797233`, and vertical bands to `0.932279` while every interactive entry remains above the native minimum hit size.
- The Profile showcase fan now matches the source's horizontal exposure: the one-star card remains at `-116` pt, the three-star card moves from `-76` to `-62` pt, and the resting hero moves from `28` to `60` pt. Card sizes, vertical offsets, rotations, dropped-state animation, and Drag/Flip controls are unchanged. Repeat-identical renders improve composite `0.820452` to `0.826677`, thumbnail `0.797233` to `0.804290`, histogram `0.744522` to `0.748859`, and bands `0.932279` to `0.938181`.
- The Profile showcase controls now match the source's width split: Flip horizontal padding drops from `18` to `4` pt, reducing the capsule from roughly `92` to `64` pt while the flexible Drag control receives the released width. Outer edges, height, typography, accessibility identifiers, and actions stay unchanged. Repeat-identical renders improve composite `0.826677` to `0.827358` and thumbnail `0.804290` to `0.805879`; bands move only `0.938181` to `0.937618`.
- The Profile showcase deck now uses the source-measured vertical proportions: a `358` pt deck frame, `228 x 380` pt hero, `250` pt photo window, and `118 x 274` pt supporting cards. The resting hero and supporting cards move upward with the added height so their top and bottom bounds align with the concept while every width, horizontal fan offset, rotation, dropped-state transform, gesture, and control identifier remains intact. The reference, previous baseline, and candidate were judged on one normalized canvas. All four scores improve from composite `0.833302`, thumbnail `0.815732`, histogram `0.753645`, and bands `0.935683` to `0.850142`, `0.839534`, `0.762652`, and `0.943469`; two independent final renders are pixel-identical. A fresh real-coordinate Profile replay passes Drag/Add, Flip, Send Card, Compare, rail Add, Trade Later, and center Capture through the final `tab:capture` event. This supersedes the earlier `228 x 338` hero and `208` pt photo-window geometry.
- Current material QA references are `qa-shots/swiftui-native-capture-shaderkit-v1.png` and `qa-shots/swiftui-native-binder-shaderkit-rarity-v1.png`.
- The July 13 Friends/Profile geometry pass fixed the three viewport defects found against `friends-showcase-stack.png`: the second Friend Activity row's locality/date line no longer hides behind the action rail, the hero showcase card no longer overlaps the "Drag to showcase" pill, and the white Profile bottom bar now uses the concept's "Collection" label. Current layout-weighted concept scores are Capture `0.819`, Binder `0.855`, and Friends `0.827`.
- The full July 13 real-coordinate pass is green across navigation, Map, Capture, Binder, and Profile. The Profile action-rail taps were recalibrated from `0.83` to `0.85` of the Simulator display after the latest viewport compaction, and every asserted action now reaches its intended control.
- After the Profile showcase-control pass, the Simulator build, five-tab smoke, native visual gate, static 37-event map, aggregate verification, and concept audit all pass. The earlier `0`-Simulator-window blocker was resolved by granting macOS Accessibility permission to the shell host: `System Events` now reports the booted `iPhone 17 Pro` window, and a complete five-suite coordinate pass (navigation, map, capture, binder, profile — every asserted event through the final `tab:capture`) is green at the current deck-proportions HEAD.
- A July 13 follow-up refreshed the Friends/Profile screenshot and reviewed it beside `friends-showcase-stack.png` on one canvas. A Profile-only bottom-safe-area experiment was rejected because it separated the action rail from the white navigation and would invalidate the calibrated coordinate targets; the accepted UI remains unchanged, with the current concept score still at `0.814` and all activity content visible above the rail.
- A starter `WildGoSpeciesClassifier.mlmodelc` (56 KB) is now trained, compiled, and bundled under `GeneratedAssets/`, so the Vision/Core ML offline path is active end-to-end. It was trained through `ios/ml/build-model.sh` on a synthetic dataset (196 augmented crops of the seven bundled demo-species images), validates at 100% on that set, and was spot-checked with `VNCoreMLRequest` on blue jay, turkey tail, and monarch samples. Treat it as a pipeline-proving placeholder: swap in a real labeled photo dataset with the same command to make offline classification production-grade.
- Resume from here by configuring a live Supabase project, verifying AVFoundation on physical hardware, and re-training the local Core ML model with a real labeled dataset (the bundled starter model only proves the pipeline). Source-image similarity is intentionally not the current optimization target.

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
- [`ShaderKit`](https://github.com/jamesrochabrun/ShaderKit) is wired into the native SwiftUI target as an exact `1.2.4` SPM dependency. One shared system now gives every rarity its own Metal material: 1-star matte steel, 2-star colored alloy, 3-star crosshatched silver, 4-star iridescent pearl, 5-star inverted foil, and 6-star rainbow holo. Capture's drag tilt feeds ShaderKit directly while flip and four-card pagination remain independent. `npm run goal:audit` fails if the dependency, resolved revision, six-tier mapping, shader effects, or current Capture/Binder material references disappear.

## What Is Implemented

- Mobile-first Vite 8 + React 19 prototype retained for design comparison; `@vitejs/plugin-react` is on 6.x and the lockfile is fully current.
- Native SwiftUI iOS shell that builds and runs in the iPhone simulator.
- SwiftData local persistence, AVFoundation camera preview and still capture, PhotosUI import, MapKit location views, and CoreLocation capture metadata.
- Captured/imported JPEGs are normalized, saved under the app support `ObservationPhotos` folder, and referenced by SwiftData cards so newly identified observations use the user's photo instead of a static demo asset.
- Cloud-first species recognition through the Supabase Edge Function, with Supabase Auth-verified signed-in user tokens, private Storage upload, and Postgres observation persistence.
- Edge Function cloud-recognition output is normalized before persistence so generous model responses still become card-safe rarity, finish, stars, confidence, notes, and alternative matches.
- Supabase Auth sessions persist the refresh token and expiry time; capture/import recognition and Profile collection sync refresh stale access tokens before sending signed-in cloud requests.
- Signed-in collection sync now uploads local-only SwiftData card photos to private Storage when the app still has the local JPEG, pushes card metadata to Postgres, pulls the user's cloud observations back into SwiftData, and caches private Storage images locally when the authenticated download succeeds.
- Vision/Core ML local recognition is wired through `VNCoreMLRequest`. `ios/ml/build-model.sh` trains (Create ML), compiles, and installs `WildGoSpeciesClassifier.mlmodelc` into the bundled `GeneratedAssets/` folder; `LocalSpeciesRecognizer` auto-discovers it there to enable local fallback/offline classification without any Xcode target edits.
- Camera capture is Simulator-hardened: `CameraSession` skips configuration on Simulator, waits briefly for a ready photo connection on device, and prevents overlapping captures, so `Add to Binder` reliably uses the demo fallback when no hardware capture is available.
- Restored iOS AppIcon asset catalog and LaunchScreen storyboard build resources.
- Six-star holographic unlock card for the capture result.
- Capture uses a generated 4:3 blue-jay park photo (`capture-blue-jay-landscape-gen-v2.png`) in both native and Web targets, avoiding source-reference screenshot crops while matching the concept's wider photo window and subject scale.
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
  - four-card horizontal paging; dots reflect only the current card and never the flip state
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
  - custom 62 pt dark treatment with raised Capture on Explore, Map, and Cards
  - reference-matched four-item white treatment on Profile; the separate action rail's center camera opens Capture
- Wildlife/privacy copy:
  - approximate location
  - location softened
  - rarity is discovery difficulty

## Validation

Commands run:

```bash
npm install
npm outdated
npm run verify   # aggregate, Simulator-free gate: goal:audit + ios:verify-events + concept:audit + supabase:verify + build
npm run build
npm run goal:audit
npm run concept:audit
deno check supabase/functions/identify-species/index.ts
npm run supabase:verify
plutil -lint ios/App/App/Info.plist
npm run ios:build
npm run ios:verify-events
npm run ios:visual-check
npm run ios:smoke
npm run ios:interactions
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
- Custom SwiftUI bottom navigation replaces the system tab bar. Explore, Map, and Cards expose all five destinations in the dark treatment; Profile uses the reference's four-item white bar while its action rail camera provides the Capture destination.
- Flip interaction reveals card back content.
- Capture Press & Hold changes card depth, and Capture Flip swaps the six-star card to a field-notes back.
- Capture unlock layout now uses geometry-based card scaling so the six-star hero card occupies more of the iPhone 17 Pro viewport like the concept reference while keeping the interaction controls, Add to Binder, and Share Card fully visible.
- Capture unlock now removes the non-reference "Cloud recognition ready" status line, restores the concept-reference "Approx location" chip on the hero card while leaving privacy softening active elsewhere, and increases the iPhone 17 Pro card scale so the hero card and CTAs fill the viewport more like `capture-holo-unlock.png`.
- Capture's latest native pass replaces the portrait demo crop with generated 4:3 landscape art, uses a true 324 x 472 pt card body instead of stretching a narrower card, restores one-line rarity and six-star chrome, adds the reference AI-confidence caption, enlarges the photo window and interaction icons, and aligns the CTA stack with the concept. The normalized concept score improved from `0.739` to `0.767` (thumbnail `0.801` to `0.828`, histogram `0.593` to `0.624`, vertical bands `0.852` to `0.880`); the audit thresholds were raised to preserve the gain.
- Capture's card stage is now lifted 4 pt to match the source's vertical rhythm. The accepted pass reaches composite `0.768`, thumbnail `0.827`, histogram `0.628`, and bands `0.882`; a larger 12 pt lift was measured and rejected because it reduced composite fidelity.
- Capture's earlier Sticker opacity pass reached composite `0.773`, thumbnail `0.832`, histogram `0.628`, and bands `0.894`. That renderer is now superseded by the ShaderKit six-tier material system; current QA prioritizes UI hierarchy, spacing, material readability, and interaction behavior over source-image similarity.
- Binder now uses fixed internal card dimensions instead of transparent outer frames around intrinsic-width children: its two feature cards and four small cards no longer overlap, names and metadata fit their slots, photo heights match the reference, and the whole surface uses the concept's quieter material saturation. Binder concept fidelity improved from `0.780` to `0.813` (histogram `0.636` to `0.712`, vertical bands `0.899` to `0.938`), with raised regression gates and a passing real-coordinate Binder interaction suite.
- The custom dark navigation raises Binder concept fidelity again to composite `0.814` (thumbnail `0.841`, histogram `0.700`, vertical bands `0.951`) while preserving all five destinations and the raised Capture button.
- Capture Share Card opens the native share sheet; Flip and Press & Hold were re-verified after the responsive layout pass.
- Capture now uses ShaderKit's foil, rainbow glitter, shimmer, and edge-shine effects for the six-star card; `swiftui-native-capture-shaderkit-v1.png` is the current material QA screenshot.
- Real-coordinate automation verified Capture Tilt, Press & Hold, Flip, Add to Binder, and Share Card. It also swipes through cards 2, 3, and 4, verifies each page event, then swipes backward while flip remains independent from the page dots. Add to Binder stays in-app and falls back to the demo image on Simulator instead of crashing when AVFoundation has no active video connection. The QA harness now fits the Simulator window onscreen before every coordinate pass so bottom actions cannot be obscured by desktop overlays.
- `npm run ios:interactions` now repeats the native button checks with real Simulator-window coordinate taps and validates the SwiftUI actions through the app's QA-only event log. It covers the full bottom navigation, Map Near me/Capture/Cards controls, Capture Back/Tilt/Press & Hold/Flip/Add/Share, Cards collection/notifications/mode tabs/layout/Tips controls, and Profile/Friends controls. It is gated by `npm run ios:verify-events`, a Simulator-free check that fails fast if any `wait_for_event` assertion no longer maps to a `showToast` string (or tab `qaName`) in `AppDelegate.swift`.
- `npm run supabase:verify` covers the cloud-recognition backend contract without live secrets, including OpenAI output normalization for confidence percentages, out-of-range stars, tier/finish synonyms, missing notes, invalid JSON, base64/data URL decoding, private Storage path construction, path-segment sanitization, observation UUID validation, Supabase Auth bearer-token verification, fail-closed missing-key behavior, explicitly disclosed demo fallback, complete injected-fetch handler flows for success and downstream rollback, Deno type checking, pinned CLI availability, and hosted-secret deployment rules.
- Signed-in recognition now uses one observation UUID across SwiftData, private Storage, and Postgres, so pulling the account does not duplicate a newly captured card. Edge writes are idempotent and return an error when Storage or Postgres persistence fails; newly uploaded images are removed through the Storage API after OpenAI/output/Postgres failure, while a pre-existing signed-in card image is preserved on failed retry. Anonymous device-path cards are migrated to the signed-in user's private path on first sync.
- `npm run goal:audit` performs a simulator-free static audit that the repo still contains the requested native iOS frameworks, SwiftData model container, AVFoundation capture path, MapKit/PhotosUI/CoreLocation usage, Supabase Postgres/Storage/RLS migration, OpenAI-backed Edge Function, Vision/Core ML fallback path, model-training tooling, concept references, native visual QA references, and the pinned ShaderKit package with all six rarity materials and current material QA references.
- `npm run concept:audit` compares the tracked native Capture, Binder, and Friends/Profile reference screenshots against the original concept images. Its composite is intentionally layout-weighted (`55%` spatial thumbnail, `25%` vertical bands, `20%` color histogram), matching the current priority on UI hierarchy and geometry while retaining a lower color-drift guardrail for catastrophic palette regressions.
- Friends Flip swaps the showcase card to its back, and Drag/Add to Showcase changes the visible showcase slot state.
- Friends/Profile `v16` tightens the reference-style action rail so long labels fit, restores a visible trade/friends icon with a supported SF Symbol, and reduces the back-card typography so the small cards read as a physical stack instead of cropped posters.
- Friends/Profile now separates that five-action rail from a four-item white bottom navigation like the concept. The white bar labels the binder destination "Collection" to match the reference.
- Friends/Profile `v17` compacts the profile column (stack spacing `8`, activity spacing `11`, rail bottom inset `16`) so both Friend Activity rows render fully above the action rail in the initial viewport, and separates the hero showcase card from the "Drag to showcase" pill instead of overlapping it.
- Friends/Profile's profile-stat row now matches the source's quieter scale: the avatar is `52` pt inside a `54` pt button, the level and XP line use `12` pt type, and the Cards/Places icons and values use `16`/`17` pt. Two independent renders improve composite `0.818063` to `0.820452`, thumbnail `0.791942` to `0.797233`, and vertical bands `0.931234` to `0.932279`. Histogram changes from `0.748431` to `0.744522`; the retained `0.744` guard still catches major palette drift while honoring the explicit UI/layout-first priority.
- Friends/Profile's showcase deck uses a `358` pt frame, a `228 x 380` pt hero card, a `250` pt image window, and `118 x 274` pt supporting cards. These current measured dimensions supersede the earlier `228 x 338` hero and `208` pt image window. Its former Sticker overlay is superseded by the shared six-star ShaderKit rainbow-holo material.
- Friends/Profile's resting showcase fan uses source-matched horizontal offsets (`-116`, `-62`, `60`) so all three card faces retain the intended visible width without altering the interactive dropped state.
- Friends/Profile's Drag/Flip row uses a source-matched flexible/compact split: Drag expands into the width released by the compact `4` pt Flip padding without moving either outside edge.
- Friend Activity now uses the measured source geometry: `44` pt avatars, `132` pt text tracks, `58 x 48` pt card thumbnails, `28` pt thumbnail-to-XP breathing room, `9` pt section spacing, and compact XP capsules. Four candidates were compared with the concept and prior baseline on one canvas; the accepted pass improves composite `0.827358` to `0.831345`, thumbnail `0.805879` to `0.813856`, and histogram `0.748596` to `0.748662`. Vertical bands move to `0.935966`, accepted because the measured row geometry visibly matches the source more closely. Two independent final renders differ in only `22` of `3,162,132` pixels, with mean channel delta `0.000047`. The current desktop-coordinate replay reached `launch:profile`, but macOS reported zero Simulator windows, so this pass relies on the successful 37-event source mapping plus five-tab native smoke instead of claiming live coordinate taps.
- Friend Activity's vertical placement now uses `16` pt top padding instead of the former `-12` pt compression. Normalized source measurement showed about `27` pt between the showcase controls and activity heading and about `9` pt between the second row and action rail; the accepted offset matches both gaps without overlap. Three candidates (`12`, `16`, and `20` pt) were compared beside the source and prior baseline. The `16` pt pass improves composite `0.831345` to `0.832205`, thumbnail `0.813856` to `0.815068`, and histogram `0.748662` to `0.750039`; bands remain guarded at `0.9355`. Two independent renders again differ in only `22` pixels with mean channel delta `0.000047`. The current coordinate replay again reached `launch:profile`, but macOS exposed zero Simulator windows; the five-tab native smoke, Profile visual reference, and 37-event source mapping all pass.
- Profile's two bottom surfaces now share the concept's lower screen anchor: the root white navigation compensates `24` pt of the device bottom inset while the five-action rail removes its former `16` pt lift. An explicit white Profile root background prevents the negative inset from exposing the gray `TabView` host. Zero-offset, navigation-only (`-12`, `-18`, `-24`), combined (`-24/0`), and boundary (`-32/-8`) candidates were compared on one canvas. The accepted `-24/0` combination improves composite `0.832205` to `0.833302`, thumbnail `0.815068` to `0.815732`, histogram `0.750039` to `0.753645`, and bands `0.935639` to `0.935683`. Two independent final renders are pixel-identical. A live Simulator-window coordinate pass then verified Drag/Add, Flip, Send Card, Compare, rail Add, Trade Later, and the center Capture action, including the final `tab:capture` transition.
- The Profile hero, Capture card, Map detail card, Binder feature cards, Binder small cards, and Binder list thumbnails now all use `RarityMetalBorder`; lower rarities no longer fall back to plain SwiftUI strokes.
- Real-coordinate automation verified Friends Drag to showcase, Flip, Send Card, Compare, rail Add to Showcase, Trade Later, and the rail Capture destination after the custom-navigation pass.
- Binder List view now switches to a real list board, and Grid view returns to the reference-style binder grid.
- Binder sorting changes both the menu label and the visible card ordering; Rarity sorting was verified in Simulator.
- Binder Tips opens the native alert, and toast feedback renders below the Dynamic Island safe area.
- Add to Binder updates button state.
- 5-6 rarity filter returns the five-star and six-star cards.
- Map, binder, and capture screens render without visual overlap.
- `npm run ios:visual-check` parses the generated native smoke PNGs without GUI access and fails if any core tab screenshot is missing, too small, mostly transparent, too low-contrast, visually collapsed into too few sampled color buckets, or materially drifts from the tracked native reference screenshots for Capture, Cards, Profile, and Map.
- Friends showcase stack keeps intentional card overflow without colliding with the bottom navigation.
- iOS simulator launches full screen with restored app icon and launch storyboard resources compiled by Xcode.

## Run Locally

```bash
cd wild-go-mvp
npm install
npm run dev -- --port 5173
```

Local design tooling was force-refreshed from the official
[`pbakaus/impeccable` `skill-v3.9.1`](https://github.com/pbakaus/impeccable/releases/tag/skill-v3.9.1)
Codex skill artifact. Reinstall the same pinned artifact with
`install-skill-from-github.py --repo pbakaus/impeccable --ref skill-v3.9.1 --path .agents/skills/impeccable`.

Then open:

```text
http://127.0.0.1:5173
```

## Run iOS

```bash
cd wild-go-mvp
npm install
npm run goal:audit
npm run concept:audit
npm run ios:build
npm run ios:smoke
npm run ios:visual-check
npm run ios:interactions
xcrun simctl install booted ios/App/build-native/Build/Products/Debug-iphonesimulator/App.app
xcrun simctl launch booted com.wildgo.mvp
```

Use `npm run ios:open` to continue in Xcode. Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `ios/debug.xcconfig` or Xcode build settings before testing against a live Supabase project.

For visual QA, run `npm run ios:smoke` with a booted Simulator. The script installs the app, launches the key tabs with a timeout, and writes screenshots under the ignored `qa-shots/native-smoke/` folder. You can still pass a tab override manually, such as `xcrun simctl launch booted com.wildgo.mvp --wildgo-tab capture`, `--wildgo-tab binder`, or `--wildgo-tab profile`.

For interaction QA, run `npm run ios:interactions` with the Simulator window visible and macOS Accessibility click permission enabled for the shell. The script uses real window-coordinate taps against the full bottom navigation plus Capture, Cards, and Profile/Friends, then reads `Documents/wildgo-qa-events.log` from the app's Simulator data container to confirm each SwiftUI button action fired. It first runs `npm run ios:verify-events` (`ios/qa-check-events.sh`), which needs no Simulator or build and can run in CI to catch toast-string or tab-name drift before spending time on a launch.

## Product Notes

The card system is intentionally original. It borrows the general emotional appeal of collectible trading cards but avoids copying Pokemon card layouts, marks, type symbols, or franchise-specific visual language.

The strongest MVP loop is:

```text
Capture -> AI likely match -> six-star/rarity reveal -> add to binder -> share/showcase
```

## Recommended Next Steps

1. Configure live Supabase project values and secrets for end-to-end cloud recognition/storage. **Tooling provided:**
   - Copy `ios/debug.xcconfig.example` to `ios/debug.xcconfig` and add your project URL + anon key.
   - Run `supabase/deploy.sh` (links project, `db push`, sets secrets, deploys the function). See `supabase/functions/identify-species/.env.example` for local serving.
   - Set `OPENAI_API_KEY`; the Edge Function fails fast without it unless `ALLOW_DEMO_IDENTIFICATION=true` is explicitly enabled for local demos.
   - Confirm `SUPABASE_ANON_KEY` is available to the Edge Function so signed-in user JWTs can be verified through Supabase Auth before `user_id` is trusted for Storage/Postgres writes.
   - Secrets are now gitignored (`ios/debug.xcconfig` holds only the public anon key + URL; `.env`/service-role/OpenAI keys never get committed).
2. ~~Add Supabase Auth screens and user-account syncing for card collections.~~ **Done:** Profile avatar opens the auth sheet; signed-in users refresh expired access tokens, upload local card photos to private Storage when available, push binder metadata to Postgres, and pull cloud observations back into SwiftData.
3. Test AVFoundation still-photo capture on physical devices (needs hardware). ~~Tune simulator fallbacks.~~ **Done:** `CameraSession` short-circuits on Simulator, polls up to 1.5s for a ready photo connection before falling back, and guards against overlapping captures so the demo fallback stays reliable.
4. ~~Train/export `WildGoSpeciesClassifier.mlmodelc` and add it to the Xcode target to activate local/offline classification.~~ **Done (starter model):** a 56 KB classifier trained on synthetic augmentations of the seven demo-species images is bundled in `GeneratedAssets/` and verified with Vision spot checks, so the offline path is live. Re-run `ios/ml/build-model.sh <real_dataset>` with real labeled photos to replace it for production-grade accuracy (no `.pbxproj` edits needed).
5. ~~Expand card backs with habitat, seasonality, safety guidance, and confidence alternatives.~~ **Done:** `SpeciesFieldGuide` powers capture card backs and cloud responses can return `alternativeMatches`.
6. ~~Add share-card export as an image.~~ **Done:** Share Card now exports a rendered card image plus text through the native share sheet.
7. ~~Add privacy rules for sensitive species and exact locations.~~ **Done:** `PrivacyLocationPolicy` softens map pins and locality labels for sensitive/high-rarity finds.

## Known Limitations

- The SwiftUI app includes local SwiftData persistence and a Supabase Edge Function path for Storage/Postgres persistence, but live cloud recognition requires project secrets. Missing `OPENAI_API_KEY` is now a hard configuration error unless local demo fallback is explicitly enabled.
- Authentication is implemented with email/password against Supabase Auth, including persisted refresh-token sessions for capture/import recognition and Profile sync. Edge Function requests with signed-in JWTs are verified through Supabase Auth before assigning `user_id`; magic-link confirmation may still be required depending on project auth settings.
- Collection sync now has a bidirectional Postgres/SwiftData merge plus authenticated local-photo Storage upload, but conflict handling is intentionally simple: local rows are matched by UUID or uploaded Storage path, and remote-only rows use generated placeholder art when private Storage image download is unavailable.
- Vision + Core ML local recognition now ships with a bundled starter classifier, but it was trained on synthetic augmentations of the seven demo images, so real-world photos of unlisted species will fall back to the generic card. Replace it by running `ios/ml/build-model.sh` with a real labeled dataset.
- Physical-device AVFoundation capture still needs on-hardware verification; the Simulator path is covered by the demo fallback.
