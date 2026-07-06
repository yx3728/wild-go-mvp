# Wild Go on-device species classifier

This folder builds `WildGoSpeciesClassifier.mlmodelc`, the optional Core ML model
that powers offline/local species recognition when the Supabase cloud path is
unreachable. Without a bundled model the app still works — it uses the cloud
Edge Function and, failing that, the sample fallback card.

## Requirements

- macOS with Xcode installed (Create ML and `coremlcompiler` ship in the toolchain).

## Dataset layout

One subfolder per species label, images inside:

```text
dataset/
  blue_jay/            *.jpg / *.png
  northern_cardinal/
  eastern_gray_squirrel/
  black_eyed_susan/
  rock_pigeon/
  monarch_butterfly/
  turkey_tail/
```

Label folder names should normalize (underscores/dashes → spaces, lowercased) to a
match string in `LocalSpeciesCatalog` (see `ios/App/App/AppDelegate.swift`) so a
prediction maps onto card rarity, finish, and copy. Unmapped labels still classify;
they just render as a generic 1-star "Urban Nature Find" card.

Aim for at least ~20–40 varied images per class for a usable transfer-learning model.

## Build + install

```bash
ios/ml/build-model.sh path/to/dataset
npm run ios:build
```

`build-model.sh` trains the model, compiles it to `.mlmodelc`, and copies it into
`ios/App/App/GeneratedAssets/`. Because that folder is a bundled folder reference,
the next iOS build ships the model and `LocalSpeciesRecognizer` finds it
automatically at `GeneratedAssets/WildGoSpeciesClassifier.mlmodelc`.

## Manual steps (optional)

```bash
# 1. Train only
swift ios/ml/train_species_classifier.swift path/to/dataset ios/ml/build

# 2. Compile only
xcrun coremlcompiler compile ios/ml/build/WildGoSpeciesClassifier.mlmodel ios/ml/build

# 3. Install into the app bundle assets
cp -R ios/ml/build/WildGoSpeciesClassifier.mlmodelc ios/App/App/GeneratedAssets/
```

To verify the app picked it up, launch and trigger a capture with the cloud path
disabled (no `SUPABASE_URL`); recognition should still return a mapped card.
