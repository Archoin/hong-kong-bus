#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$godot_bin" ]]; then godot_bin="$(command -v godot)"; fi
for suite in test_rules test_gameplay; do
  test_log="$(mktemp /tmp/hkbus-check.XXXXXX)"
  if ! "$godot_bin" --headless --path "$project_dir" --script "tests/$suite.gd" -- --test-mode >"$test_log" 2>&1; then
    cat "$test_log"
    rm -f "$test_log"
    exit 1
  fi
  cat "$test_log"
  if rg -q 'SCRIPT ERROR:|ERROR:|FAIL:' "$test_log"; then
    rm -f "$test_log"
    exit 1
  fi
  rm -f "$test_log"
done
