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
PRODUCT.md
public/assets/
docs/card-visuals/
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

## What Is Implemented

- Mobile-first Vite + React prototype.
- Camera/photo-library input using `accept="image/*"` and `capture="environment"`.
- Immediate local preview of the uploaded photo as a new collectible card.
- Mock likely-match transition with filename-seeded demo results for the bundled species assets.
- Six-star holographic unlock card for the capture result.
- Creature cards using real generated nature photo assets.
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
  - press depth
  - flip to card back
  - add-to-binder state
  - rarity filtering
  - social showcase toggle
- Expanded card backs:
  - habitat
  - seasonality
  - similar-species alternatives
  - location privacy
  - wildlife-safe guidance
- Share action using Web Share when available and clipboard copy as the fallback.
- Bottom navigation:
  - Explore
  - Friends
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
```

QA artifacts:

```text
design-qa.md
qa-shots/capture-viewport.png
qa-shots/cards-viewport.png
qa-shots/friends-viewport.png
qa-shots/comparison-source-implementation.png
qa-shots/upload-capture-viewport.png
qa-shots/card-back-details.png
```

QA result:

```text
final result: passed
```

Browser checks covered:

- 390 x 844 primary mobile viewport and 320 x 700 narrow-screen check.
- No horizontal overflow.
- All creature images load.
- Bottom navigation renders all five destinations.
- Flip interaction reveals card back content.
- Add to Binder updates button state.
- Add to Binder stays disabled while the mock identification is running.
- Uploading the bundled flower photo resolves to Black-eyed Susan and preserves the uploaded image.
- The upload ribbon stays inside the photo area and does not overlap the card title.
- Share Card copies the species, rarity, and privacy summary when Web Share is unavailable.
- 5-6 rarity filter returns the five-star and six-star cards.
- Showcase action toggles state on the Friends screen.
- Browser console remains free of errors during the upload and flip flow.

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

## Product Notes

The card system is intentionally original. It borrows the general emotional appeal of collectible trading cards but avoids copying Pokemon card layouts, marks, type symbols, or franchise-specific visual language.

The strongest MVP loop is:

```text
Capture -> AI likely match -> six-star/rarity reveal -> add to binder -> share/showcase
```

## Recommended Next Steps

1. Replace the filename-seeded demo matcher with a real identification API that returns candidates and calibrated confidence.
2. Persist uploaded observations, card state, and binder membership in Supabase or Firebase.
3. Add upload failure, unsupported-file, retake, and low-confidence states.
4. Add device-orientation foil movement on mobile with a reduced-motion fallback.
5. Export the composed card as a shareable image instead of sharing text only.
6. Add enforceable privacy rules for sensitive species and exact locations.
7. Package the validated mobile web flow as React Native or a PWA once backend scope is chosen.

## Known Limitations

- Species and social data are currently mocked in `src/App.jsx`.
- Uploaded photos use temporary browser object URLs and disappear on refresh.
- AI matching is a filename-seeded demo, not a real model or identification API.
- The app has no backend, authentication, or persistence yet.
- Share Card exports text only; it does not render a card image yet.
- Foil movement uses pointer/touch position, not physical device gyroscope.
- The MVP is optimized for mobile web, not packaged as React Native yet.
