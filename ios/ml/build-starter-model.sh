#!/usr/bin/env bash
# Rebuilds the deterministic seven-species starter model used by automated QA.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
ASSET_DIR="$REPO_ROOT/ios/App/App/GeneratedAssets"
MODEL_PATH="$BUILD_DIR/WildGoSpeciesClassifier.mlmodel"
COMPILED_PATH="$BUILD_DIR/WildGoSpeciesClassifier.mlmodelc"
INSTALLED_PATH="$ASSET_DIR/WildGoSpeciesClassifier.mlmodelc"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if ! "$PYTHON_BIN" -c 'import coremltools, numpy, PIL' >/dev/null 2>&1; then
  echo "Missing Python model tools. Install ios/ml/requirements-starter.txt first." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
"$PYTHON_BIN" "$SCRIPT_DIR/build_starter_model.py" "$ASSET_DIR" "$MODEL_PATH"

rm -rf "$COMPILED_PATH"
xcrun coremlcompiler compile "$MODEL_PATH" "$BUILD_DIR"

rm -rf "$INSTALLED_PATH"
cp -R "$COMPILED_PATH" "$INSTALLED_PATH"

"$SCRIPT_DIR/verify-model.sh"
