#!/usr/bin/env bash
# tools/run-tests.sh — run the GUT suite headless (Linux/WSL/CI).
# Exit 0 = all tests pass, 1 = a test failed, 2 = no Godot binary found.
# Override the binary with: GODOT=/path/to/godot tools/run-tests.sh
set -euo pipefail

export GODOT_DISABLE_LEAK_CHECKS=1
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot binary not found. Set \$GODOT or add 'godot' to PATH." >&2
  exit 2
fi

# Fresh checkouts (e.g. CI) have no built .godot/ — warm-up import so class_name scripts register.
if [ ! -d "$ROOT/.godot" ]; then
  "$GODOT" --headless --path "$ROOT" --import --quit || true
fi

exec "$GODOT" --headless --display-driver headless --audio-driver Dummy --disable-render-loop \
  --path "$ROOT" -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
