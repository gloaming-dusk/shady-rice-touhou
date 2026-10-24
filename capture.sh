#!/usr/bin/env bash
# Take the rice's screenshots from a live headless session (1280x720, or
# CAPTURE_SIZE=1920x1080):
#   desktop, notification, cutin, launcher, close, bad-apple, shortcuts
# into shots/, and preview.jpg from the desktop.
#
#   SHADY_ROOT=~/src/shady nix develop ~/src/shady -c ./capture.sh
#
# Needs a Shady build, a GPU, foot, busctl and dbus-run-session. The shell
# runs on a private session bus with stand-ins for wpctl, nmcli and
# playerctl and a fixed set of applications (capture/), so nothing of this
# machine shows. Bad Apple!! plays only if you made its frames
# (tools/bad-apple.sh in Shady).
set -euo pipefail
RICE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SHADY_ROOT:-$RICE/../shady}" && pwd)"
for bin in shady shady-shell; do
    [[ -x "$ROOT/build/$bin" ]] || { echo "capture: $ROOT/build/$bin is missing" >&2; exit 1; }
done
for tool in dbus-run-session busctl foot; do
    command -v "$tool" >/dev/null || { echo "capture: needs $tool" >&2; exit 1; }
done
if [[ -z "${GENSOKYO_CAPTURE_BUS:-}" ]]; then
    exec env GENSOKYO_CAPTURE_BUS=1 dbus-run-session -- "$0" "$@"
fi
[[ -e "$RICE/build/libshady-plugin-point-items.so" ]] || SHADY_ROOT="$ROOT" "$RICE/build.sh"

work="$(mktemp -d /tmp/gensokyo-capture.XXXXXX)"
trap 'rm -rf "$work"' EXIT
mkdir -m 700 "$work/runtime" "$work/data"
: >"$work/status"
printf 'include=%s\n[main]\nfont=monospace:size=10\n' "$RICE/extras/foot.ini" >"$work/foot.ini"
(
    export XDG_RUNTIME_DIR="$work/runtime"
    unset WAYLAND_DISPLAY WAYLAND_SOCKET SHADY_SOCKET
    export WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDERER=gles2
    export SHADY_ROOT="$ROOT" SHADY_TOUHOU_DIR="$RICE"
    export SHADY_LUA_INIT="$RICE/capture/init.lua"
    export SHADY_SHELL_BIN="$ROOT/build/shady-shell"
    export SHADY_SHELL_CONFIG="$RICE/shell.lua"
    export CAPTURE_OUT="$work" CAPTURE_STATUS="$work/status" CAPTURE_FOOT_INI="$work/foot.ini"
    export PATH="$RICE/capture/bin:$PATH"
    export XDG_DATA_DIRS="$RICE/capture"
    # Your Bad Apple!! frames and panel picture, if you have them.
    export SHADY_BAD_APPLE_DIR="${SHADY_BAD_APPLE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/shady/bad-apple}"
    export SHADY_BAD_APPLE_PLAYER="${SHADY_BAD_APPLE_PLAYER:-true}"
    export SHADY_TOUHOU_PORTRAIT="${SHADY_TOUHOU_PORTRAIT:-${XDG_DATA_HOME:-$HOME/.local/share}/shady/touhou/portrait.png}"
    export XDG_DATA_HOME="$work/data"
    exec "$ROOT/build/shady" -c "$RICE/config.lua"
) >"$work/shady.log" 2>&1 &
pid=$!
for _ in $(seq 1 3000); do
    grep -q '^DONE$' "$work/status" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
done
wait "$pid" 2>/dev/null || true
grep -q '^DONE$' "$work/status" || { echo "capture: did not finish" >&2; tail -n 60 "$work/shady.log" >&2; exit 1; }
mkdir -p "$RICE/shots"
cp "$work"/*.png "$RICE/shots/"
cp "$work/shady.log" "$RICE/shots/shady.log"
echo "capture: $(ls "$RICE/shots" | tr '\n' ' ')"
