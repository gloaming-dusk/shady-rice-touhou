#!/usr/bin/env bash
# Make Gensokyo your Shady session's rice by linking its files into
# ~/.config/shady, which shady-session prefers over the built-in rices.
#
#   ./install.sh              link config.lua, init.lua, shell.lua, shaders/ and fonts/
#   ./install.sh --uninstall  remove those links again
#
# Files of your own already there are left alone: the script stops and
# names them instead.
set -euo pipefail

RICE="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/shady"
FILES=(config.lua init.lua shell.lua shaders fonts)

ours() { [[ -L "$1" && "$(readlink "$1")" == "$RICE/$2" ]]; }

if [[ "${1:-}" == "--uninstall" ]]; then
  for f in "${FILES[@]}"; do
    if ours "$DEST/$f" "$f"; then rm "$DEST/$f" && echo "removed $DEST/$f"; fi
  done
  exit 0
fi

conflicts=()
for f in "${FILES[@]}"; do
  if [[ -e "$DEST/$f" || -L "$DEST/$f" ]] && ! ours "$DEST/$f" "$f"; then
    conflicts+=("$DEST/$f")
  fi
done
if (( ${#conflicts[@]} )); then
  echo "Gensokyo: these already exist; move them aside first:" >&2
  printf '  %s\n' "${conflicts[@]}" >&2
  exit 1
fi

mkdir -p "$DEST"
for f in "${FILES[@]}"; do
  ln -sfn "$RICE/$f" "$DEST/$f"
  echo "linked $DEST/$f"
done
echo "Log out and pick the Shady session; the shell reloads shell.lua edits live."
