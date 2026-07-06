#!/usr/bin/env bash
# Simulator-free guard for the interaction QA suite.
#
# Parses every `wait_for_event "toast:..."` / `"launch:..."` / `"tab:..."`
# assertion in
# qa-interactions.sh and confirms the matching source exists in AppDelegate.swift
# (a showToast literal, or a WildGoTab.qaName value). This catches the common
# regression where a toast string or tab name is renamed/inverted and the
# coordinate suite then fails only after a full build + Simulator run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERACTIONS="${INTERACTIONS:-$REPO_ROOT/ios/qa-interactions.sh}"
SOURCE="${SOURCE:-$REPO_ROOT/ios/App/App/AppDelegate.swift}"

for path in "$INTERACTIONS" "$SOURCE"; do
  if [[ ! -f "$path" ]]; then
    echo "Required file not found: $path" >&2
    exit 1
  fi
done

missing=0
checked=0

while IFS= read -r event; do
  kind="${event%%:*}"
  value="${event#*:}"
  checked=$((checked + 1))

  case "$kind" in
    toast)
      if ! grep -Fq "showToast(" "$SOURCE" || ! grep -Fq "\"$value\"" "$SOURCE"; then
        echo "MISSING toast literal in AppDelegate.swift: \"$value\"" >&2
        missing=$((missing + 1))
      fi
      ;;
    launch | tab)
      if ! grep -Fq "return \"$value\"" "$SOURCE"; then
        echo "MISSING WildGoTab.qaName value in AppDelegate.swift: \"$value\"" >&2
        missing=$((missing + 1))
      fi
      ;;
    *)
      echo "Unknown event kind in assertion: $event" >&2
      missing=$((missing + 1))
      ;;
  esac
done < <(
  grep -oE 'wait_for_event "(toast|launch|tab):[^"]*"' "$INTERACTIONS" \
    | sed -E 's/^wait_for_event "([^"]*)"$/\1/' \
    | sort -u
)

if [[ "$checked" -eq 0 ]]; then
  echo "No wait_for_event assertions found in $INTERACTIONS" >&2
  exit 1
fi

if [[ "$missing" -gt 0 ]]; then
  echo "QA event check failed: $missing of $checked assertions have no source match." >&2
  exit 1
fi

echo "QA event check passed: all $checked interaction assertions map to AppDelegate.swift sources."
