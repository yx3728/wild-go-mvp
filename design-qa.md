**Findings**
- No P0/P1/P2 findings remain in the current native Capture comparison.
- The generated 4:3 blue-jay asset is used by the app; no visual-reference screenshot is shipped as card art.
- The iPhone 17 Pro Dynamic Island remains visible because this is a real Simulator capture, while the concept omits device hardware chrome. This is an expected P3 platform difference.
- The Binder board now uses non-overlapping, reference-measured card slots. The two feature cards and four small cards render complete faces instead of drawing outside transparent outer frames.

**Comparison Evidence**
- Source visual truth: `docs/card-visuals/capture-holo-unlock.png` (`853 x 1844`).
- Native implementation: `qa-shots/swiftui-native-capture-layout-final.png` (`1206 x 2622`).
- State: six-star Blue Jay unlock, front face, first page dot, idle recognition state.
- The four dots are now semantic pagination for four complete cards. Horizontal drag moves through all four pages; flipping only changes the current card face and leaves `activeCardIndex` unchanged.
- Both images use the same normalized phone aspect and are compared by thumbnail pixels, color histogram, and vertical layout bands.
- Binder source: `docs/card-visuals/binder-rarity-grid.png`; native implementation: `qa-shots/swiftui-native-binder-grid-layout-final.png`.
- Friends/Profile source: `docs/card-visuals/friends-showcase-stack.png`; native implementation: `qa-shots/swiftui-native-friends-profile-v17.png`.

**Required Fidelity Surfaces**
- Fonts and typography: rarity stays on one line; six stars, species hierarchy, AI confidence, first-seen metadata, control labels, and CTA text remain readable without truncation.
- Spacing and layout: the native card now uses a true `324 x 472` pt body, a taller photo window, 84 pt interaction controls, and a CTA stack positioned near the source proportions with no overlap.
- Colors and visual tokens: dark park backdrop, lime actions, gold metadata, and Sticker-driven spectral material preserve the source hierarchy. Sticker retains the package example parameters.
- Image quality and assets: `capture-blue-jay-landscape-gen-v2.png` is generated at `1448 x 1086`, uses a landscape park composition, and is bundled independently for native and Web targets.
- Copy and content: `New card unlocked`, `Approx location`, `Likely match`, `AI confidence`, `First seen`, `Add to Binder`, and `Share Card` match the source state.

**Iteration Evidence**
- Friend Activity row geometry: normalized source measurement set avatars to `44` pt, card thumbnails to `58 x 48` pt, text tracks to `132` pt, and the card-to-XP breathing room to `28` pt. Four candidates were rendered and judged with the source and baseline on one canvas; candidate B best preserves the source's compact avatar/card scale and horizontal separation. Composite improves `0.827358` to `0.831345`, thumbnail `0.805879` to `0.813856`, and histogram `0.748596` to `0.748662`; bands move to `0.935966`, accepted under the UI/layout-first priority. Two independent renders differ in only `22` of `3,162,132` pixels with mean channel delta `0.000047`. Gates are now composite `0.831`, thumbnail `0.8135`, histogram `0.7485`, and bands `0.9355`. The current coordinate replay reached `launch:profile`, but macOS exposed zero Simulator windows, preventing desktop-coordinate taps; the 37-event source mapping and five-tab smoke/visual checks still pass.
- Profile showcase control-width ratio: normalized measurement showed Drag at `50.4%` of screen width versus `58.1%` in the source, while Flip was `23.7%` versus `15.4%`. Reducing only Flip's horizontal padding from `18` to `4` pt brings the capsule from roughly `92` to `64` pt and lets the flexible Drag control absorb the released width; outer edges, height, typography, identifiers, and actions remain unchanged. Three candidates were compared beside the source on one canvas. Two independent final renders are pixel-identical and improve composite `0.826677` to `0.827358` and thumbnail `0.804290` to `0.805879`; histogram is `0.748596` and bands move only `0.938181` to `0.937618`. Gates are now composite `0.827`, thumbnail `0.8055`, histogram `0.748`, and bands `0.9375`.
- Profile showcase horizontal fan: the one-star card stays at `-116` pt, the three-star card moves from `-76` to `-62` pt, and the resting hero moves from `28` to `60` pt. Card dimensions, vertical offsets, rotations, dropped-state animation, and controls remain unchanged. Three measured candidates were compared beside the source on one canvas; candidate C wins all four metrics. Two independent final renders are pixel-identical and improve composite `0.820452` to `0.826677`, thumbnail `0.797233` to `0.804290`, histogram `0.744522` to `0.748859`, and bands `0.932279` to `0.938181`. Gates are now composite `0.826`, thumbnail `0.804`, histogram `0.748`, and bands `0.938`.
- Profile stat-row hierarchy: the account avatar is now `52` pt inside a `54` pt button, its level badge is `22` pt, level/XP typography is `12` pt, and Cards/Places use `16` pt icons with `17` pt values. The tighter source-matched row lifts the showcase deck without changing any downstream component. Two independent renders produce the same six-decimal metrics and improve composite `0.818063` to `0.820452`, thumbnail `0.791942` to `0.797233`, and bands `0.931234` to `0.932279`; histogram changes from `0.748431` to `0.744522`, accepted under the explicit UI/layout-first priority. Gates are now composite `0.820`, thumbnail `0.797`, histogram `0.744`, and bands `0.932`.
- Friend Activity type density: section title `16` pt, See all/title/subtitle `12` pt, detail `10` pt, and XP `11` pt now match the source's compact hierarchy. A fixed `24` pt heading row and unchanged `54` pt avatars preserve button geometry. Two renders match exactly and improve composite `0.816452` to `0.818063`, thumbnail `0.788859` to `0.791942`, and bands `0.931082` to `0.931234`; histogram moves slightly from `0.749045` to `0.748431`, accepted because the explicit priority is UI layout over image/color similarity. Gates are now composite `0.8175`, thumbnail `0.7915`, histogram `0.748`, and bands `0.931`.
- Profile metadata hierarchy: the three labels now use concept-matched semantic accents (purple rarity, green AI, blue captured), while values use `12` pt bold and secondary details use `6.5` pt semibold. A color-only trial was insufficient; the complete hierarchy produces repeat-identical gains from composite `0.815983` to `0.816452`, thumbnail `0.788328` to `0.788859`, and histogram `0.747889` to `0.749045`, with bands remaining `0.931`. Gates are now composite `0.816`, thumbnail `0.7885`, histogram `0.7485`, and bands `0.931`.
- Profile hero-card text hierarchy: reducing only the over-photo common name, Latin name, and star row matches the concept's quieter image caption without changing the `228 x 338` pt card or any gesture area. Six-decimal comparison improves composite from `0.815941` to `0.815983`, thumbnail from `0.788237` to `0.788328`, and bands from `0.931069` to `0.931299`; histogram moves only from `0.748217` to `0.747889`. A follow-up metadata-glass trial was rejected because histogram fidelity fell to `0.740` and composite to `0.814`. Gates are now composite `0.815`, thumbnail `0.788`, histogram `0.747`, and bands `0.931`.
- Friends/Profile top-bar typography: replacing the oversized rounded display faces with restrained system sans at `22` pt and `20` pt keeps the notification-owned row height and every control frame unchanged. Two independent renders both improve composite fidelity from `0.814` to `0.816`, thumbnail similarity from `0.786` to `0.788`, and vertical bands from `0.930` to `0.931`, with histogram stable at `0.748`. Gates are now composite `0.814`, thumbnail `0.787`, histogram `0.746`, and bands `0.930`.
- Capture secondary CTA material: darkening only the Share Card fill and replacing its bright lime outline with a muted olive border preserves the exact button geometry while moving the lower action stack toward the concept. Two independent candidate renders both score composite `0.819`, thumbnail `0.843`, histogram `0.624`, and bands `0.922`; previous tracked values were composite `0.818`, thumbnail `0.843`, histogram `0.620`, and bands `0.922`. Gates are now composite `0.818`, thumbnail `0.840`, histogram `0.623`, and bands `0.920`.
- Before: composite `0.739`, thumbnail `0.801`, histogram `0.593`, bands `0.852`.
- After: composite `0.767`, thumbnail `0.828`, histogram `0.624`, bands `0.880`.
- Regression gates were raised to composite `0.760`, thumbnail `0.820`, histogram `0.610`, and bands `0.870`.
- Capture vertical alignment: a measured 4 pt stage lift improves composite to `0.768`, histogram to `0.628`, and bands to `0.882` while thumbnail remains `0.827`. Gates are now composite `0.765`, thumbnail `0.825`, histogram `0.620`, and bands `0.880`; the 12 pt trial was rejected because its composite dropped to `0.764`.
- Capture dark foil surface: reducing only the outer metadata-surface `HoloShine` opacity from `0.40` to `0.16` keeps Sticker's example parameters and photo/frame effects intact while matching the concept's black card base. Composite rises to `0.773`, thumbnail to `0.832`, and bands to `0.894`; gates are now composite `0.770`, thumbnail `0.830`, histogram `0.625`, and bands `0.890`.
- Binder before: composite `0.780`, thumbnail `0.840`, histogram `0.636`, bands `0.899`; the previous score masked visible card overlap.
- Binder after: composite `0.813`, thumbnail `0.836`, histogram `0.712`, bands `0.938`. New gates are composite `0.800`, thumbnail `0.830`, histogram `0.700`, and bands `0.930`.
- Custom-navigation Binder: composite `0.814`, thumbnail `0.841`, histogram `0.700`, bands `0.951`. The flat 62 pt dark bar improves the concept's vertical bands and keeps the raised Capture action.
- Custom-navigation Friends/Profile: composite `0.769`, thumbnail `0.768`, histogram `0.700`, bands `0.892`. The screen now matches the source's four-item white bottom navigation and separate five-action rail; gates were raised to composite `0.765`, thumbnail `0.760`, histogram `0.690`, and bands `0.890`.
- Taller Friends/Profile showcase: composite `0.777`, thumbnail `0.776`, histogram `0.703`, bands `0.907`. The hero card is now `228 x 338` pt with a `208` pt photo window, matching the concept's taller physical-card proportion while the lighter Sticker example overlay keeps the cardinal clear. Gates are now composite `0.773`, thumbnail `0.772`, histogram `0.700`, and bands `0.900`.
- Full-strength Profile foil frame: retaining Sticker's README example parameters while raising only the rendered frame opacity from `0.72` to `0.95` improves composite to `0.778`, histogram to `0.706`, and bands to `0.910`. Gates are now composite `0.775`, thumbnail `0.774`, histogram `0.703`, and bands `0.907`; the equivalent Binder opacity trial was rejected because thumbnail similarity regressed.

**Implementation Checklist**
- [x] Use generated landscape wildlife art instead of a screenshot crop.
- [x] Match card aspect, photo proportion, rarity chrome, confidence block, interaction rail, dots, and CTA rhythm.
- [x] Match the Share Card fill and border material to the concept without changing its icon, label, frame, or hit target.
- [x] Match Friends/Profile's top-bar type hierarchy without changing the notification or downstream interaction geometry.
- [x] Match the Profile hero card's over-photo species hierarchy while preserving card size, material, and gestures.
- [x] Match the Profile hero metadata's semantic colors and type scale without changing columns, dividers, material, or hit targets.
- [x] Match Friend Activity's compact typography while preserving the heading row and activity-button geometry.
- [x] Match the Profile stats row's avatar, level, XP, Cards, and Places hierarchy while keeping every entry point above the native minimum hit size.
- [x] Match the Profile showcase fan's three horizontal exposure widths while preserving card sizes, rotations, vertical offsets, dropped state, and Drag/Flip interactions.
- [x] Match the Profile Drag/Flip width ratio while preserving the row's outer edges, height, typography, accessibility identifiers, and actions.
- [x] Match Friend Activity avatar, text-track, card-thumbnail, XP-gap, and row-spacing geometry against normalized source measurements.
- [x] Preserve Sticker's official example shader parameters and native motion path.
- [x] Re-run real-coordinate Capture interactions after the layout change. CGEvent taps verify Back, Tilt, Press & Hold, Flip, Add to Binder, and Share Card; horizontal CGEvent drags verify pages 2, 3, and 4 plus a backward swipe, with internal carousel events for every asserted page.
- [x] Move the Capture card stage upward by the smallest measured amount that improves the normalized concept score, then re-run Back, Tilt, Depth, Flip, Add, and Share using real coordinates.
- [x] Measure `0.40`, `0.28`, and `0.16` Sticker-surface presentation variants together, retain the darkest improving pass, and preserve the package's example shader parameters.
- [x] Pass native build, visual, concept, backend, and Web gates.
- [x] Constrain Binder feature and small-card artwork, text, foil, and backgrounds to measured slots.
- [x] Match Binder photo heights and reduce the screen saturation to the reference material palette.
- [x] Re-run all Binder controls with real Simulator-window coordinate taps.
- [x] Replace the system tab bar with adaptive SwiftUI navigation: five dark-mode destinations on Explore/Map/Binder and four light-mode destinations on Profile, where the action rail's center camera is the Capture entry.
- [x] Re-run full navigation plus every Profile action-rail button using real Simulator-window coordinate taps.
- [x] Increase the Friends/Profile hero and supporting-card heights to the measured concept proportions, reject the heavy foil-bloom trial, and re-run Drag/Flip at their new real coordinates.
- [x] Verify Sticker usage against the pinned package README/source, restore the Profile frame's package output to `0.95`, and reject the Binder variant after the comparison showed no composite gain.

**Follow-up Polish**
- Physical-device review can judge the accelerometer-driven foil phase; static Simulator screenshots only capture one shader angle.
- Simulator's macOS window does not forward the bottom-edge Share Card CGEvent consistently. Strict failure is the default; `STRICT_SHARE_COORDINATE_QA=0` is available only for diagnosing that host-window limitation. The final clean-state run logged `toast:Opening share sheet` and passed without the fallback.
- Binder Tips remains intentionally scrollable on iPhone 17 Pro; its real-coordinate interaction passes after the custom navigation height reduction.

**Result**
- `final result: passed`
