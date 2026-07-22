#!/usr/bin/env bash
# Drives real Simulator-window coordinate taps and verifies SwiftUI actions by
# reading the app's QA-only interaction log from its data container.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$REPO_ROOT/ios/App/build-native/Build/Products/Debug-iphonesimulator/App.app}"
BUNDLE_ID="${BUNDLE_ID:-com.wildgo.mvp}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-12}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-2}"
EVENT_TIMEOUT_SECONDS="${EVENT_TIMEOUT_SECONDS:-5}"
TAP_SETTLE_SECONDS="${TAP_SETTLE_SECONDS:-0.8}"
QA_INTERACTION_SUITES="${QA_INTERACTION_SUITES:-navigation map capture binder profile offline}"
STRICT_SHARE_COORDINATE_QA="${STRICT_SHARE_COORDINATE_QA:-1}"
QA_LOG_RELATIVE_PATH="Documents/wildgo-qa-events.log"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Run npm run ios:build first, or use npm run ios:interactions." >&2
  exit 1
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_ID="$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/ { print $2; exit }')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No booted iOS Simulator found. Boot one in Simulator.app or set DEVICE_ID." >&2
  exit 1
fi

DEVICE_NAME="$(
  xcrun simctl list devices booted \
    | awk -F' \\(' -v device_id="$DEVICE_ID" 'index($0, device_id) { sub(/^ +/, "", $1); print $1; exit }'
)"

if [[ -z "$DEVICE_NAME" ]]; then
  echo "Could not resolve Simulator device name for $DEVICE_ID." >&2
  exit 1
fi

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
  shift
  local -a extra_arguments
  extra_arguments=("$@")

  for attempt in $(seq 1 "$LAUNCH_ATTEMPTS"); do
    local launch_status=0
    if (( ${#extra_arguments[@]} )); then
      run_with_timeout "$LAUNCH_TIMEOUT_SECONDS" "simctl launch $tab" \
        xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
          --wildgo-tab "$tab" --wildgo-qa-interactions --wildgo-reset-qa-log \
          "${extra_arguments[@]}" || launch_status=$?
    else
      run_with_timeout "$LAUNCH_TIMEOUT_SECONDS" "simctl launch $tab" \
        xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
          --wildgo-tab "$tab" --wildgo-qa-interactions --wildgo-reset-qa-log \
          || launch_status=$?
    fi

    if [[ "$launch_status" -eq 0 ]]; then
      return 0
    fi

    echo "    launch retry $attempt/$LAUNCH_ATTEMPTS for $tab" >&2
    run_with_timeout 5 "simctl terminate after failed $tab" \
      xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null || true
    sleep 2
  done

  return 1
}

app_container() {
  xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data
}

qa_log_path() {
  local container
  container="$(app_container)"
  printf '%s/%s\n' "$container" "$QA_LOG_RELATIVE_PATH"
}

wait_for_event() {
  local expected="$1"
  local log_path
  log_path="$(qa_log_path)"

  for _ in $(seq 1 "$EVENT_TIMEOUT_SECONDS"); do
    if [[ -f "$log_path" ]] && grep -Fq "$expected" "$log_path"; then
      echo "    event: $expected"
      return 0
    fi
    sleep 1
  done

  echo "Missing QA event: $expected" >&2
  if [[ -f "$log_path" ]]; then
    echo "--- QA log ---" >&2
    cat "$log_path" >&2
    echo "--------------" >&2
  else
    echo "QA log not found: $log_path" >&2
  fi
  return 1
}

simulator_display_metrics() {
  osascript - "$DEVICE_NAME" <<'APPLESCRIPT'
on run argv
  set wantedName to item 1 of argv
  tell application "Simulator" to activate
  delay 0.2
  tell application "System Events"
    tell process "Simulator"
      try
        click menu item "Fit Screen" of menu 1 of menu bar item "Window" of menu bar 1
        delay 0.4
      end try
      repeat with simulatorWindow in windows
        if (name of simulatorWindow as text) contains wantedName then
          set displayGroup to group 1 of simulatorWindow
          set displayPosition to position of displayGroup
          set displaySize to size of displayGroup
          return (item 1 of displayPosition as text) & " " & (item 2 of displayPosition as text) & " " & (item 1 of displaySize as text) & " " & (item 2 of displaySize as text)
        end if
      end repeat
    end tell
  end tell
  error "Simulator window not found for " & wantedName
end run
APPLESCRIPT
}

read -r DISPLAY_X DISPLAY_Y DISPLAY_WIDTH DISPLAY_HEIGHT <<< ""

refresh_display_metrics() {
  open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
  sleep 1
  read -r DISPLAY_X DISPLAY_Y DISPLAY_WIDTH DISPLAY_HEIGHT <<< "$(simulator_display_metrics)"

  if [[ -z "$DISPLAY_X" || -z "$DISPLAY_Y" || -z "$DISPLAY_WIDTH" || -z "$DISPLAY_HEIGHT" ]]; then
    echo "Could not read Simulator display metrics." >&2
    exit 1
  fi
}

tap_relative() {
  local relative_x="$1"
  local relative_y="$2"
  local label="$3"

  local screen_x
  local screen_y
  screen_x="$(awk -v left="$DISPLAY_X" -v width="$DISPLAY_WIDTH" -v rel="$relative_x" 'BEGIN { printf "%d", left + (width * rel) }')"
  screen_y="$(awk -v top="$DISPLAY_Y" -v height="$DISPLAY_HEIGHT" -v rel="$relative_y" 'BEGIN { printf "%d", top + (height * rel) }')"

  echo "    tap: $label at display ${relative_x},${relative_y} -> screen ${screen_x},${screen_y}"
  swift - "$screen_x" "$screen_y" <<'SWIFT'
import CoreGraphics
import Foundation

let x = Double(CommandLine.arguments[1]) ?? 0
let y = Double(CommandLine.arguments[2]) ?? 0
let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)

CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
    .post(tap: .cghidEventTap)
usleep(100_000)
CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?
    .post(tap: .cghidEventTap)
usleep(120_000)
CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?
    .post(tap: .cghidEventTap)
SWIFT
  sleep "$TAP_SETTLE_SECONDS"
}

drag_relative() {
  local start_relative_x="$1"
  local start_relative_y="$2"
  local end_relative_x="$3"
  local end_relative_y="$4"
  local label="$5"

  local start_x
  local start_y
  local end_x
  local end_y
  start_x="$(awk -v left="$DISPLAY_X" -v width="$DISPLAY_WIDTH" -v rel="$start_relative_x" 'BEGIN { printf "%d", left + (width * rel) }')"
  start_y="$(awk -v top="$DISPLAY_Y" -v height="$DISPLAY_HEIGHT" -v rel="$start_relative_y" 'BEGIN { printf "%d", top + (height * rel) }')"
  end_x="$(awk -v left="$DISPLAY_X" -v width="$DISPLAY_WIDTH" -v rel="$end_relative_x" 'BEGIN { printf "%d", left + (width * rel) }')"
  end_y="$(awk -v top="$DISPLAY_Y" -v height="$DISPLAY_HEIGHT" -v rel="$end_relative_y" 'BEGIN { printf "%d", top + (height * rel) }')"

  echo "    drag: $label at display ${start_relative_x},${start_relative_y} -> ${end_relative_x},${end_relative_y}"
  swift - "$start_x" "$start_y" "$end_x" "$end_y" <<'SWIFT'
import CoreGraphics
import Foundation

let startX = Double(CommandLine.arguments[1]) ?? 0
let startY = Double(CommandLine.arguments[2]) ?? 0
let endX = Double(CommandLine.arguments[3]) ?? 0
let endY = Double(CommandLine.arguments[4]) ?? 0
let source = CGEventSource(stateID: .hidSystemState)
let start = CGPoint(x: startX, y: startY)
let end = CGPoint(x: endX, y: endY)

CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left)?
    .post(tap: .cghidEventTap)
for step in 1...12 {
    let progress = Double(step) / 12.0
    let point = CGPoint(
        x: start.x + (end.x - start.x) * progress,
        y: start.y + (end.y - start.y) * progress
    )
    CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
    usleep(25_000)
}
CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)?
    .post(tap: .cghidEventTap)
SWIFT
  sleep "$TAP_SETTLE_SECONDS"
}

run_capture_suite() {
  echo "==> Interaction suite: capture"
  launch_tab "capture"
  sleep 2
  wait_for_event "launch:capture"
  refresh_display_metrics

  tap_relative 0.15 0.10 "capture back"
  wait_for_event "toast:Back to Explore"
  wait_for_event "tab:explore"

  launch_tab "capture"
  sleep 2
  wait_for_event "launch:capture"
  refresh_display_metrics

  tap_relative 0.28 0.725 "capture tilt"
  wait_for_event "toast:Tilt shimmer is active"

  tap_relative 0.50 0.725 "capture depth"
  wait_for_event "toast:Depth preview opened"

  tap_relative 0.73 0.725 "capture flip"
  wait_for_event "toast:Card details side shown"

  drag_relative 0.78 0.46 0.22 0.46 "capture swipe to card 2"
  wait_for_event "carousel:capture:2"

  drag_relative 0.78 0.46 0.22 0.46 "capture swipe to card 3"
  wait_for_event "carousel:capture:3"

  drag_relative 0.78 0.46 0.22 0.46 "capture swipe to card 4"
  wait_for_event "carousel:capture:4"

  drag_relative 0.22 0.46 0.78 0.46 "capture swipe back to card 3"
  wait_for_event "carousel:capture:3"

  launch_tab "capture"
  sleep 2
  wait_for_event "launch:capture"
  refresh_display_metrics

  tap_relative 0.50 0.87 "capture take photo"
  wait_for_event "toast:Opening camera..."
  wait_for_event "capture:photoReady"
  wait_for_event "toast:Simulator photo ready to save"

  tap_relative 0.50 0.87 "capture save to binder"
  wait_for_event "capture:savedToBinder"
  wait_for_event "toast:Saved to Binder"
  wait_for_event "tab:binder"
  wait_for_event "binder:containsCapturedPhoto"

  launch_tab "capture"
  sleep 2
  wait_for_event "launch:capture"
  refresh_display_metrics

  tap_relative 0.50 0.92 "capture share card"
  if ! wait_for_event "toast:Opening share sheet"; then
    if [[ "$STRICT_SHARE_COORDINATE_QA" == "1" ]]; then
      return 1
    fi

    echo "    note: Simulator did not forward the bottom-edge CGEvent; run the Computer Use coordinate check for capture.shareCard"
  fi
}

run_navigation_suite() {
  echo "==> Interaction suite: navigation"
  launch_tab "explore"
  sleep 2
  wait_for_event "launch:explore"
  refresh_display_metrics

  tap_relative 0.33 0.94 "tab map"
  wait_for_event "tab:map"

  tap_relative 0.67 0.94 "tab cards"
  wait_for_event "tab:binder"

  tap_relative 0.85 0.94 "tab profile"
  wait_for_event "tab:profile"

  tap_relative 0.15 0.94 "tab explore"
  wait_for_event "tab:explore"

  tap_relative 0.50 0.94 "tab capture"
  wait_for_event "tab:capture"
}

run_map_suite() {
  echo "==> Interaction suite: map"
  launch_tab "map"
  sleep 2
  wait_for_event "launch:map"
  refresh_display_metrics

  tap_relative 0.50 0.53 "map placeholder capture"
  wait_for_event "toast:Opening Capture"
  wait_for_event "tab:capture"

  launch_tab "map"
  sleep 2
  wait_for_event "launch:map"
  refresh_display_metrics

  tap_relative 0.50 0.61 "map placeholder binder"
  wait_for_event "toast:Opening Binder"
  wait_for_event "tab:binder"
}

run_binder_suite() {
  echo "==> Interaction suite: binder"
  launch_tab "binder"
  sleep 2
  wait_for_event "launch:binder"
  refresh_display_metrics

  tap_relative 0.45 0.095 "binder collection selector"
  wait_for_event "toast:Collection selector opened"

  tap_relative 0.94 0.095 "binder notifications"
  wait_for_event "toast:Notifications opened"

  tap_relative 0.36 0.145 "binder stacks tab"
  wait_for_event "toast:Stacks selected"

  tap_relative 0.56 0.145 "binder missions tab"
  wait_for_event "toast:Missions selected"

  tap_relative 0.80 0.145 "binder friends tab"
  wait_for_event "toast:Opening Friends"
  wait_for_event "tab:profile"

  launch_tab "binder"
  sleep 2
  wait_for_event "launch:binder"
  refresh_display_metrics

  tap_relative 0.90 0.18 "binder list layout"
  wait_for_event "toast:List view selected"
  sleep 1.5

  tap_relative 0.81 0.18 "binder grid layout"
  wait_for_event "toast:Grid view selected"

  drag_relative 0.50 0.81 0.50 0.55 "binder scroll to tips"

  tap_relative 0.79 0.76 "binder tips"
  wait_for_event "toast:Binder tips opened"
}

run_profile_suite() {
  echo "==> Interaction suite: profile"
  launch_tab "profile"
  sleep 2
  wait_for_event "launch:profile"
  refresh_display_metrics

  tap_relative 0.50 0.53 "friends placeholder capture"
  wait_for_event "toast:Opening Capture"
  wait_for_event "tab:capture"

  launch_tab "profile"
  sleep 2
  wait_for_event "launch:profile"
  refresh_display_metrics

  tap_relative 0.50 0.61 "friends placeholder binder"
  wait_for_event "toast:Opening Binder"
  wait_for_event "tab:binder"
}

run_offline_suite() {
  echo "==> Interaction suite: offline recognition"
  launch_tab "capture" --wildgo-qa-offline-recognition
  wait_for_event "offline:recognition:blue_jay"
}

echo "==> Installing $BUNDLE_ID on $DEVICE_ID"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

IFS=' ' read -r -a suites <<< "$QA_INTERACTION_SUITES"
for suite in "${suites[@]}"; do
  case "$suite" in
    navigation)
      run_navigation_suite
      ;;
    map)
      run_map_suite
      ;;
    capture)
      run_capture_suite
      ;;
    binder)
      run_binder_suite
      ;;
    profile)
      run_profile_suite
      ;;
    offline)
      run_offline_suite
      ;;
    *)
      echo "Unknown interaction suite: $suite" >&2
      exit 1
      ;;
  esac
done

echo "Native iOS interaction QA passed for suites: $QA_INTERACTION_SUITES"
