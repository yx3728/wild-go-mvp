**Findings**
- No P0/P1/P2 findings remain in the current native Capture comparison.
- The generated 4:3 blue-jay asset is used by the app; no visual-reference screenshot is shipped as card art.
- The iPhone 17 Pro Dynamic Island remains visible because this is a real Simulator capture, while the concept omits device hardware chrome. This is an expected P3 platform difference.
- The Binder board now uses non-overlapping, reference-measured card slots. The two feature cards and four small cards render complete faces instead of drawing outside transparent outer frames.

**Comparison Evidence**
- Source visual truth: `docs/card-visuals/capture-holo-unlock.png` (`853 x 1844`).
- Native implementation: `qa-shots/swiftui-native-capture-layout-final.png` (`1206 x 2622`).
- State: six-star Blue Jay unlock, front face, first page dot, idle recognition state.
- Both images use the same normalized phone aspect and are compared by thumbnail pixels, color histogram, and vertical layout bands.
- Binder source: `docs/card-visuals/binder-rarity-grid.png`; native implementation: `qa-shots/swiftui-native-binder-grid-layout-final.png`.
- Friends/Profile source: `docs/card-visuals/friends-showcase-stack.png`; native implementation: `qa-shots/swiftui-native-friends-profile-v16.png`.

**Required Fidelity Surfaces**
- Fonts and typography: rarity stays on one line; six stars, species hierarchy, AI confidence, first-seen metadata, control labels, and CTA text remain readable without truncation.
- Spacing and layout: the native card now uses a true `324 x 472` pt body, a taller photo window, 84 pt interaction controls, and a CTA stack positioned near the source proportions with no overlap.
- Colors and visual tokens: dark park backdrop, lime actions, gold metadata, and Sticker-driven spectral material preserve the source hierarchy. Sticker retains the package example parameters.
- Image quality and assets: `capture-blue-jay-landscape-gen-v2.png` is generated at `1448 x 1086`, uses a landscape park composition, and is bundled independently for native and Web targets.
- Copy and content: `New card unlocked`, `Approx location`, `Likely match`, `AI confidence`, `First seen`, `Add to Binder`, and `Share Card` match the source state.

**Iteration Evidence**
- Before: composite `0.739`, thumbnail `0.801`, histogram `0.593`, bands `0.852`.
- After: composite `0.767`, thumbnail `0.828`, histogram `0.624`, bands `0.880`.
- Regression gates were raised to composite `0.760`, thumbnail `0.820`, histogram `0.610`, and bands `0.870`.
- Binder before: composite `0.780`, thumbnail `0.840`, histogram `0.636`, bands `0.899`; the previous score masked visible card overlap.
- Binder after: composite `0.813`, thumbnail `0.836`, histogram `0.712`, bands `0.938`. New gates are composite `0.800`, thumbnail `0.830`, histogram `0.700`, and bands `0.930`.
- Custom-navigation Binder: composite `0.814`, thumbnail `0.841`, histogram `0.700`, bands `0.951`. The flat 62 pt dark bar improves the concept's vertical bands and keeps the raised Capture action.
- Custom-navigation Friends/Profile: composite `0.769`, thumbnail `0.768`, histogram `0.700`, bands `0.892`. The screen now matches the source's four-item white bottom navigation and separate five-action rail; gates were raised to composite `0.765`, thumbnail `0.760`, histogram `0.690`, and bands `0.890`.
- Taller Friends/Profile showcase: composite `0.777`, thumbnail `0.776`, histogram `0.703`, bands `0.907`. The hero card is now `228 x 338` pt with a `208` pt photo window, matching the concept's taller physical-card proportion while the lighter Sticker example overlay keeps the cardinal clear. Gates are now composite `0.773`, thumbnail `0.772`, histogram `0.700`, and bands `0.900`.

**Implementation Checklist**
- [x] Use generated landscape wildlife art instead of a screenshot crop.
- [x] Match card aspect, photo proportion, rarity chrome, confidence block, interaction rail, dots, and CTA rhythm.
- [x] Preserve Sticker's official example shader parameters and native motion path.
- [x] Re-run real-coordinate Capture interactions after the layout change. CGEvent taps verified Back, Tilt, Press & Hold, Flip, and Add to Binder; a Computer Use coordinate tap at `198,790` verified Share Card and logged `toast:Opening share sheet` while opening the native share sheet.
- [x] Pass native build, visual, concept, backend, and Web gates.
- [x] Constrain Binder feature and small-card artwork, text, foil, and backgrounds to measured slots.
- [x] Match Binder photo heights and reduce the screen saturation to the reference material palette.
- [x] Re-run all Binder controls with real Simulator-window coordinate taps.
- [x] Replace the system tab bar with adaptive SwiftUI navigation: five dark-mode destinations on Explore/Map/Binder and four light-mode destinations on Profile, where the action rail's center camera is the Capture entry.
- [x] Re-run full navigation plus every Profile action-rail button using real Simulator-window coordinate taps.
- [x] Increase the Friends/Profile hero and supporting-card heights to the measured concept proportions, reject the heavy foil-bloom trial, and re-run Drag/Flip at their new real coordinates.

**Follow-up Polish**
- Physical-device review can judge the accelerometer-driven foil phase; static Simulator screenshots only capture one shader angle.
- Simulator's macOS window does not forward the bottom-edge Share Card CGEvent consistently. Strict failure is the default; `STRICT_SHARE_COORDINATE_QA=0` is available only for diagnosing that host-window limitation. The final clean-state run logged `toast:Opening share sheet` and passed without the fallback.
- Binder Tips remains intentionally scrollable on iPhone 17 Pro; its real-coordinate interaction passes after the custom navigation height reduction.

**Result**
- `final result: passed`
