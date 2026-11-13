#!/usr/bin/env bash
# Imports the project and runs the headless smoke test.
# Fails on a non-zero exit code or on any script error in the output.
# Usage: tools/ci_check.sh [path-to-godot]   (defaults to "godot" on PATH)
set -euo pipefail

GODOT="${1:-godot}"
cd "$(dirname "$0")/.."

echo "== Importing project =="
"$GODOT" --headless --path . --import 2>&1 | tee /tmp/talkon_import.log

echo "== Running smoke test =="
set +e
"$GODOT" --headless --path . res://tests/smoke_test.tscn 2>&1 | tee /tmp/talkon_test.log
status=${PIPESTATUS[0]}
set -e

if grep -E "SCRIPT ERROR|Parse Error|^ERROR:" /tmp/talkon_import.log /tmp/talkon_test.log; then
  echo "Engine reported errors."
  exit 1
fi
if ! grep -q "SMOKE TEST PASSED" /tmp/talkon_test.log; then
  echo "Smoke test did not pass."
  exit 1
fi
exit "$status"
