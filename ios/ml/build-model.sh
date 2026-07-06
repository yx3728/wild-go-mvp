#!/usr/bin/env bash
# Trains, compiles, and installs the on-device Wild Go species classifier.
#
# Usage:
#   ios/ml/build-model.sh <dataset_dir>
#
# Steps:
#   1. Trains WildGoSpeciesClassifier.mlmodel from a labeled image dataset.
#   2. Compiles it to WildGoSpeciesClassifier.mlmodelc with coremlcompiler.
#   3. Installs the compiled model into ios/App/App/GeneratedAssets so the next
#      `npm run ios:build` bundles it and the app enables offline classification.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <dataset_dir>" >&2
  exit 2
fi

DATASET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
GENERATED_ASSETS_DIR="$REPO_ROOT/ios/App/App/GeneratedAssets"

mkdir -p "$BUILD_DIR"

echo "==> Training Create ML classifier"
swift "$SCRIPT_DIR/train_species_classifier.swift" "$DATASET_DIR" "$BUILD_DIR"

MODEL_PATH="$BUILD_DIR/WildGoSpeciesClassifier.mlmodel"
if [[ ! -e "$MODEL_PATH" ]]; then
  echo "Expected model not found at $MODEL_PATH" >&2
  exit 1
fi

echo "==> Compiling to .mlmodelc"
xcrun coremlcompiler compile "$MODEL_PATH" "$BUILD_DIR"

COMPILED_PATH="$BUILD_DIR/WildGoSpeciesClassifier.mlmodelc"
if [[ ! -e "$COMPILED_PATH" ]]; then
  echo "Compilation did not produce $COMPILED_PATH" >&2
  exit 1
fi

echo "==> Installing into app bundle assets"
rm -rf "$GENERATED_ASSETS_DIR/WildGoSpeciesClassifier.mlmodelc"
cp -R "$COMPILED_PATH" "$GENERATED_ASSETS_DIR/"

echo "Done. Rebuild the app to bundle the model:"
echo "  npm run ios:build"
