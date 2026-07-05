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
- Showcase action toggles state on the Friends screen.

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

1. Add real camera/photo upload input.
2. Replace mocked AI match data with an identification API.
3. Persist card collection state in Supabase or Firebase.
4. Add device-orientation foil movement on mobile.
5. Expand card backs with habitat, seasonality, safety guidance, and confidence alternatives.
6. Add share-card export as an image.
7. Add privacy rules for sensitive species and exact locations.

## Known Limitations

- All data is currently mocked in `src/App.jsx`.
- Photos are generated local assets, not user uploads.
- The app has no backend, authentication, or persistence yet.
- Foil movement uses pointer/touch position, not physical device gyroscope.
- The MVP is optimized for mobile web, not packaged as React Native yet.
