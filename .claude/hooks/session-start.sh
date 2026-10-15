#!/bin/bash
# Prepara a sessão do Claude Code na nuvem: Godot de console + libs Python.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VER="4.7.1"
GODOT_DIR="$HOME/.local/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VER}-stable_linux.x86_64"

if [ ! -x "$GODOT_BIN" ]; then
  mkdir -p "$GODOT_DIR"
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_linux.x86_64.zip"
  unzip -q -o "$tmp/godot.zip" -d "$GODOT_DIR"
  rm -rf "$tmp"
  chmod +x "$GODOT_BIN"
fi

python3 -m pip install -q pillow zstandard

echo "export GODOT=\"$GODOT_BIN\"" >> "$CLAUDE_ENV_FILE"

# Importa os assets uma vez (cria .godot/), senão o primeiro teste falha.
cd "$CLAUDE_PROJECT_DIR"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
