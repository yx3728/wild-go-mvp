# Wild Go on-device species classifier

This folder owns `WildGoSpeciesClassifier.mlmodelc`, the Core ML model that powers
offline/local species recognition when the Supabase cloud path is unreachable.
The repo ships a deterministic seven-species starter model for runtime QA and a
Create ML training path for replacing it with a production dataset.

## Requirements

- macOS with Xcode installed (Create ML and `coremlcompiler` ship in the toolchain).
- Python dependencies in `requirements-starter.txt` only when rebuilding the
  bundled starter model.

## Verify the bundled model

```bash
npm run ios:verify-model
npm run ios:offline-recognition
```

The first command runs all seven generated reference images through Core ML and
Vision on macOS. The second builds and installs the app, then verifies that the
same model returns Blue Jay inside the Simulator app process. Simulator inference
uses CPU-only Core ML; physical devices retain all compute units.

## Rebuild the QA starter

```bash
python3 -m venv /tmp/wildgo-coreml
/tmp/wildgo-coreml/bin/pip install -r ios/ml/requirements-starter.txt
PYTHON_BIN=/tmp/wildgo-coreml/bin/python npm run ios:build-starter-model
```

The starter uses standard average-pooling, inner-product, and softmax Core ML
operators. It deliberately proves the bundled inference pipeline, not real-world
species accuracy.

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

## Train and install a production model

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

After replacing the starter, run both verification commands above. Create ML's
ScenePrint transfer-learning model may require final runtime validation on a
physical device even when it passes the macOS verifier.
