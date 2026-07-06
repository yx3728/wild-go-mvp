#!/usr/bin/env bash
# Installs the native app, launches key tabs, and captures screenshots with a
# hard timeout around simctl launch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$REPO_ROOT/ios/App/build-native/Build/Products/Debug-iphonesimulator/App.app}"
BUNDLE_ID="${BUNDLE_ID:-com.wildgo.mvp}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/qa-shots/native-smoke}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-12}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-2}"
SIMCTL_TIMEOUT_SECONDS="${SIMCTL_TIMEOUT_SECONDS:-10}"
SCREENSHOT_DELAY_SECONDS="${SCREENSHOT_DELAY_SECONDS:-3}"
RENDER_TIMEOUT_SECONDS="${RENDER_TIMEOUT_SECONDS:-12}"
MIN_SCREENSHOT_BYTES="${MIN_SCREENSHOT_BYTES:-120000}"
WILDGO_SMOKE_TABS="${WILDGO_SMOKE_TABS:-capture binder profile map explore}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Run npm run ios:build first, or use npm run ios:smoke." >&2
  exit 1
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_ID="$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/ { print $2; exit }')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No booted iOS Simulator found. Boot one in Simulator.app or set DEVICE_ID." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "==> Installing $BUNDLE_ID on $DEVICE_ID"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

run_with_timeout() {
  local timeout_seconds="$1"
  local label="$2"
  shift 2

  local log_file
  log_file="$(mktemp)"

  "$@" >"$log_file" 2>&1 &
  local command_pid=$!

  for _ in $(seq 1 "$timeout_seconds"); do
    if ! kill -0 "$command_pid" >/dev/null 2>&1; then
      local status=0
      wait "$command_pid" || status=$?
      cat "$log_file"
      rm -f "$log_file"
      return "$status"
    fi
    sleep 1
  done

  kill -INT "$command_pid" >/dev/null 2>&1 || true
  sleep 1
  kill -KILL "$command_pid" >/dev/null 2>&1 || true
  wait "$command_pid" >/dev/null 2>&1 || true

  local escaped_bundle
  escaped_bundle="${BUNDLE_ID//./\\.}"
  if [[ "$label" == simctl\ launch* ]] && grep -Eq "^${escaped_bundle}: [0-9]+$" "$log_file"; then
    cat "$log_file"
    rm -f "$log_file"
    return 0
  fi

  echo "$label timed out after ${timeout_seconds}s" >&2
  cat "$log_file" >&2
  rm -f "$log_file"
  return 124
}

launch_tab() {
  local tab="$1"

  for attempt in $(seq 1 "$LAUNCH_ATTEMPTS"); do
    if run_with_timeout "$LAUNCH_TIMEOUT_SECONDS" "simctl launch $tab" \
      xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" --wildgo-tab "$tab"; then
      return 0
    fi

    echo "    launch retry $attempt/$LAUNCH_ATTEMPTS for $tab" >&2
    run_with_timeout 5 "simctl terminate after failed $tab" \
      xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null || true
    sleep 2
  done

  return 1
}

capture_screenshot() {
  local tab="$1"
  local screenshot="$2"

  for _ in $(seq 1 "$RENDER_TIMEOUT_SECONDS"); do
    run_with_timeout "$SIMCTL_TIMEOUT_SECONDS" "simctl screenshot $tab" \
      xcrun simctl io "$DEVICE_ID" screenshot "$screenshot" >/dev/null

    if [[ -s "$screenshot" ]]; then
      local bytes
      bytes="$(wc -c < "$screenshot" | tr -d ' ')"
      if [[ "$bytes" -ge "$MIN_SCREENSHOT_BYTES" ]]; then
        return 0
      fi
    fi

    sleep 1
  done

  echo "Screenshot stayed below ${MIN_SCREENSHOT_BYTES} bytes: $screenshot" >&2
  return 1
}

IFS=' ' read -r -a tabs <<< "$WILDGO_SMOKE_TABS"
for tab in "${tabs[@]}"; do
  echo "==> Launching tab: $tab"
  launch_tab "$tab"
  sleep "$SCREENSHOT_DELAY_SECONDS"

  screenshot="$OUTPUT_DIR/${tab}.png"
  capture_screenshot "$tab" "$screenshot"

  if command -v sips >/dev/null 2>&1; then
    width="$(sips -g pixelWidth "$screenshot" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
    dimensions="${width:-?}x${height:-?}"
    echo "    screenshot: $screenshot ${dimensions:+($dimensions)}"
  else
    echo "    screenshot: $screenshot"
  fi
done

echo "Native iOS smoke passed for tabs: $WILDGO_SMOKE_TABS"
