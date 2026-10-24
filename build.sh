#!/usr/bin/env bash
# Build the rice's compositor plugin (point-items) against a Shady checkout.
#
#   SHADY_ROOT=~/src/shady ./build.sh
#
# SHADY_ROOT defaults to ../shady next to this repository. Writes
# build/libshady-plugin-point-items.so; the plugin finds its shaders in
# plugins/shaders from there.
set -euo pipefail

RICE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${SHADY_ROOT:-$RICE/../shady}"
if [[ ! -f "$ROOT/include/shady/plugin.h" ]]; then
  echo "Gensokyo: no Shady checkout in $ROOT. Set SHADY_ROOT." >&2
  exit 1
fi

mkdir -p "$RICE/build"
"${CC:-cc}" -std=c11 -O2 -Wall -Wextra -fPIC -shared \
  -I"$ROOT/include" \
  -o "$RICE/build/libshady-plugin-point-items.so" \
  "$RICE/plugins/point_items.c" -ldl
echo "built $RICE/build/libshady-plugin-point-items.so"
