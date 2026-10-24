#!/usr/bin/env bash
# Run Gensokyo directly on a VT (DRM + libinput), from a TTY login.
#
#   SHADY_ROOT=~/src/shady ./run-native.sh
#
# SHADY_ROOT is a Shady checkout with a build in build/ (./tools/build.sh),
# by default ../shady next to this repository. Shady's
# tools/run-native.sh checks the session and starts the compositor.
set -euo pipefail

RICE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${SHADY_ROOT:-$RICE/../shady}"
if [[ ! -x "$ROOT/build/shady" || ! -x "$ROOT/build/shady-shell" ]]; then
  echo "Gensokyo: no Shady build in $ROOT/build. Set SHADY_ROOT to a built Shady checkout." >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"
if [[ ! -e "$RICE/build/libshady-plugin-point-items.so" ]]; then
  SHADY_ROOT="$ROOT" "$RICE/build.sh" || echo "Gensokyo: windows will close without the items" >&2
fi

export SHADY_ROOT="$ROOT"
export SHADY_TOUHOU_DIR="$RICE"
export SHADY_LUA_INIT="$RICE/init.lua"
export SHADY_SHELL_CONFIG="${SHADY_SHELL_CONFIG:-$RICE/shell.lua}"

if [[ $# -eq 0 ]]; then
  default_startup="'$ROOT/build/shady-shell' & exec ${TERMINAL:-foot}"
  set -- -s "${SHADY_STARTUP:-$default_startup}"
fi

exec "$ROOT/tools/run-native.sh" -c "$RICE/config.lua" "$@"
