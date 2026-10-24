#!/usr/bin/env bash
# Put a picture of your own in the side panel, above the clock.
#
#   tools/portrait.sh <image>      crop and convert it
#   tools/portrait.sh --remove     take it out again
#
# The picture is cropped to the panel's card (240x146, kept at three times
# that for HiDPI) and saved as a PNG in
# ${SHADY_TOUHOU_PORTRAIT:-${XDG_DATA_HOME:-~/.local/share}/shady/touhou/portrait.png},
# outside this repository: no picture ships with the rice. Needs ImageMagick
# (`nix shell nixpkgs#imagemagick`).
set -euo pipefail

out="${SHADY_TOUHOU_PORTRAIT:-${XDG_DATA_HOME:-$HOME/.local/share}/shady/touhou/portrait.png}"

if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$out" && echo "removed $out"
  exit 0
fi
if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "usage: $0 <image> | --remove" >&2
  exit 1
fi
if command -v magick >/dev/null; then convert=(magick)
elif command -v convert >/dev/null; then convert=(convert)
else
  echo "portrait: needs ImageMagick (nix shell nixpkgs#imagemagick)" >&2
  exit 1
fi

mkdir -p "$(dirname "$out")"
"${convert[@]}" "$1" -resize '720x438^' -gravity center -extent 720x438 \
  -strip "PNG32:$out"
echo "portrait: $out (the panel picks it up on its next repaint)"
