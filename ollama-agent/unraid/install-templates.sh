#!/usr/bin/env bash
# Register Ollama Cursor Agent templates as Unraid Private Apps (Community Applications).
set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/killamfkr/Cellar-loader/main/ollama-agent/unraid}"
DEST="${DEST:-/boot/config/plugins/community.applications/private/cellar-loader}"

if [[ ! -d /boot/config ]]; then
  echo "This script is meant to run on Unraid (expected /boot/config)." >&2
  exit 1
fi

mkdir -p "$DEST"
curl -fsSL "$REPO_RAW/ollama.xml" -o "$DEST/ollama.xml"
curl -fsSL "$REPO_RAW/ollama-cursor-agent.xml" -o "$DEST/ollama-cursor-agent.xml"

TUSER="${TUSER:-/boot/config/plugins/dockerMan/templates-user}"
if [[ -d "$TUSER" ]]; then
  cp -f "$DEST/ollama.xml" "$TUSER/my-ollama.xml"
  cp -f "$DEST/ollama-cursor-agent.xml" "$TUSER/my-ollama-cursor-agent.xml"
  echo "Also copied to Docker templates-user: $TUSER"
fi

echo "Templates installed under: $DEST"
echo "Open Apps → Private Apps → install ollama, then ollama-cursor-agent."
