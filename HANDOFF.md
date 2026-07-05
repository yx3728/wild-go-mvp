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
capacitor.config.json
ios/App/App.xcodeproj
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

Implementation note: card physics and material are intentionally built on existing MIT-licensed GitHub packages rather than custom one-off math:

- [`react-parallax-tilt`](https://github.com/mkosir/react-parallax-tilt) handles pointer/touch tilt, perspective, glare, and gyroscope support.
- [`card-foil`](https://github.com/sawyerWeld/card-foil) handles foil, etched, galaxy, and oil-slick finishes with reduced-motion-aware shimmer.

## What Is Implemented

- Mobile-first Vite + React prototype.
- Capacitor iOS shell that builds and runs in the iPhone simulator.
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
  - flip to card back
  - add-to-binder state
  - rarity filtering
  - social showcase toggle with a visible drop/showcase slot
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
npm run ios:sync
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/App/App.xcodeproj -target App -configuration Debug -sdk iphonesimulator26.5 CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install booted ios/App/build/Debug-iphonesimulator/App.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.wildgo.mvp
```

QA artifacts:

```text
design-qa.md
public/assets/wild-go-combo-target.png
qa-shots/ios-simulator-final-compact.png
qa-shots/ios-simulator-final-material.png
qa-shots/material-capture.png
qa-shots/material-cards.png
qa-shots/material-friends-stack.png
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
npm run ios:sync
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/App/App.xcodeproj -target App -configuration Debug -sdk iphonesimulator26.5 CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install booted ios/App/build/Debug-iphonesimulator/App.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.wildgo.mvp
```

Use `npm run ios:open` to continue in Xcode.

## Product Notes

The card system is intentionally original. It borrows the general emotional appeal of collectible trading cards but avoids copying Pokemon card layouts, marks, type symbols, or franchise-specific visual language.

The strongest MVP loop is:

```text
Capture -> AI likely match -> six-star/rarity reveal -> add to binder -> share/showcase
```

## Recommended Next Steps

1. Add real camera/photo upload input.
2. Replace mocked AI match data with an identification API.
3. Persist card collection state in Supabase or Firebase.
4. Add native camera permissions and a real capture pipeline in Capacitor.
5. Expand card backs with habitat, seasonality, safety guidance, and confidence alternatives.
6. Add share-card export as an image.
7. Add privacy rules for sensitive species and exact locations.

## Known Limitations

- All data is currently mocked in `src/App.jsx`.
- Photos are generated local assets, not user uploads.
- The app has no backend, authentication, or persistence yet.
- Device-orientation foil depends on browser/webview sensor permission and device support.
