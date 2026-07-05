# Wild Go MVP

Mobile-first prototype for Wild Go, an urban nature collection app where real organism photos become rarity-based collectible cards.

## Run

```bash
npm install
npm run dev -- --port 5173
```

Open `http://127.0.0.1:5173`.

## iOS MVP

This repo now includes a Capacitor iOS shell.

```bash
npm install
npm run ios:sync
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/App/App.xcodeproj -target App -configuration Debug -sdk iphonesimulator26.5 CODE_SIGNING_ALLOWED=NO build
```

To open the project in Xcode:

```bash
npm run ios:open
```

The native app starts the Capacitor bridge programmatically and includes the restored LaunchScreen storyboard plus AppIcon asset catalog for the current local Xcode/simulator setup.

## Prototype Highlights

- Six-star holographic card reveal.
- Physical-feeling card interactions using `react-parallax-tilt` for tilt/glare and `card-foil` for rarity foil finishes.
- Rarity-based card binder.
- Friends activity built around card stacks, visible showcase slots, and collection milestones.
- Privacy and wildlife-safety copy baked into the card system.

See [HANDOFF.md](./HANDOFF.md) for product context, validation, and next steps.
