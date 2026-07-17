#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSET_DIR="$REPO_ROOT/ios/App/App/GeneratedAssets"
MODEL_PATH="${WILDGO_COREML_MODEL_PATH:-$ASSET_DIR/WildGoSpeciesClassifier.mlmodelc}"

swift "$SCRIPT_DIR/verify_species_classifier.swift" \
  "$MODEL_PATH" \
  blue_jay "$ASSET_DIR/capture-blue-jay-landscape-gen-v2.png" \
  northern_cardinal "$ASSET_DIR/binder-cardinal-gen.png" \
  eastern_gray_squirrel "$ASSET_DIR/binder-squirrel-gen.png" \
  black_eyed_susan "$ASSET_DIR/binder-flower-gen.png" \
  rock_pigeon "$ASSET_DIR/binder-pigeon-gen.png" \
  monarch_butterfly "$ASSET_DIR/binder-butterfly-gen.png" \
  turkey_tail "$ASSET_DIR/binder-turkey-tail-gen.png"
