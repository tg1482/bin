#!/usr/bin/env bash
set -euo pipefail

TMPDIR="/tmp/howto"

# List of config files to expose
CONFIG_FILES=(
  "$HOME/.config/nvim/init.lua"
  "$HOME/.config/nvim/lua/user/keymaps.lua"
  "$HOME/.tmux.conf"
)

# Create tmp folder if not exists
mkdir -p "$TMPDIR"

# Create symlinks for each config file
for f in "${CONFIG_FILES[@]}"; do
  if [ -f "$f" ]; then
    ln -sf "$f" "$TMPDIR/$(basename "$f")"
  fi
done

# Parse args
if [ "$1" == "-q" ]; then
  QUESTION="$2"
  (cd "$TMPDIR" && claude "$QUESTION")
else
  echo "Usage: howto -q \"your question\""
fi

