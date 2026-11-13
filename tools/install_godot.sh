#!/usr/bin/env bash
# Downloads the Godot editor binary (and, with --templates, the export
# templates) for Linux. Used by CI; also handy on a fresh Linux machine.
# Usage: tools/install_godot.sh <version> <status> <dest-dir> [--templates]
#   e.g. tools/install_godot.sh 4.7.2 stable "$HOME/godot" --templates
set -euo pipefail

VERSION="$1"
STATUS="$2"
DEST="$3"
WITH_TEMPLATES="${4:-}"

TAG="${VERSION}-${STATUS}"
BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
BIN="Godot_v${TAG}_linux.x86_64"

mkdir -p "$DEST"
if [ ! -x "$DEST/godot" ]; then
  echo "Downloading Godot ${TAG}"
  curl -fsSL -o "$DEST/godot.zip" "${BASE}/${BIN}.zip"
  unzip -q -o "$DEST/godot.zip" -d "$DEST"
  mv "$DEST/${BIN}" "$DEST/godot"
  rm "$DEST/godot.zip"
  chmod +x "$DEST/godot"
fi

if [ "$WITH_TEMPLATES" = "--templates" ]; then
  TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${VERSION}.${STATUS}"
  if [ ! -f "$TEMPLATE_DIR/version.txt" ]; then
    echo "Downloading export templates ${TAG}"
    curl -fsSL -o "$DEST/templates.tpz" "${BASE}/Godot_v${TAG}_export_templates.tpz"
    mkdir -p "$TEMPLATE_DIR"
    # Only the desktop templates this project exports with.
    unzip -q -o -j "$DEST/templates.tpz" \
      "templates/version.txt" \
      "templates/linux_release.x86_64" \
      "templates/linux_debug.x86_64" \
      "templates/windows_release_x86_64.exe" \
      "templates/windows_release_x86_64_console.exe" \
      "templates/windows_debug_x86_64.exe" \
      "templates/windows_debug_x86_64_console.exe" \
      -d "$TEMPLATE_DIR"
    rm "$DEST/templates.tpz"
  fi
fi

"$DEST/godot" --version
