**Findings**
- No P0/P1/P2 findings remain in the current native Capture comparison.
- The generated 4:3 blue-jay asset is used by the app; no visual-reference screenshot is shipped as card art.
- The iPhone 17 Pro Dynamic Island remains visible because this is a real Simulator capture, while the concept omits device hardware chrome. This is an expected P3 platform difference.

**Comparison Evidence**
- Source visual truth: `docs/card-visuals/capture-holo-unlock.png` (`853 x 1844`).
- Native implementation: `qa-shots/swiftui-native-capture-layout-final.png` (`1206 x 2622`).
- State: six-star Blue Jay unlock, front face, first page dot, idle recognition state.
- Both images use the same normalized phone aspect and are compared by thumbnail pixels, color histogram, and vertical layout bands.

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

**Implementation Checklist**
- [x] Use generated landscape wildlife art instead of a screenshot crop.
- [x] Match card aspect, photo proportion, rarity chrome, confidence block, interaction rail, dots, and CTA rhythm.
- [x] Preserve Sticker's official example shader parameters and native motion path.
- [x] Re-run real-coordinate Capture interactions after the layout change. CGEvent taps verified Back, Tilt, Press & Hold, Flip, and Add to Binder; a Computer Use coordinate tap at `198,790` verified Share Card and logged `toast:Opening share sheet` while opening the native share sheet.
- [x] Pass native build, visual, concept, backend, and Web gates.

**Follow-up Polish**
- Physical-device review can judge the accelerometer-driven foil phase; static Simulator screenshots only capture one shader angle.
- Simulator's macOS window does not forward the bottom-edge Share Card CGEvent consistently. Strict failure is the default; `STRICT_SHARE_COORDINATE_QA=0` is available only for diagnosing that host-window limitation. The final clean-state run logged `toast:Opening share sheet` and passed without the fallback.

**Result**
- `final result: passed`
