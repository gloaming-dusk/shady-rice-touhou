#!/usr/bin/env bash
# A yin-yang orb and a few lines about the system, for the terminal.
#
#   tools/fetch.sh
#
# FETCH_USER, FETCH_HOST, FETCH_OS and FETCH_UPTIME override what it reads.
set -euo pipefail

r=$'\e[38;2;224;48;60m' w=$'\e[38;2;244;238;227m' g=$'\e[38;2;232;184;74m'
d=$'\e[38;2;142;134;168m' l=$'\e[38;2;232;106;122m' o=$'\e[0m'

user="${FETCH_USER:-$(id -un)}"
host="${FETCH_HOST:-$(uname -n)}"
os="${FETCH_OS:-$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$NAME}" || uname -s)}"
if [[ -n "${FETCH_UPTIME:-}" ]]; then up="$FETCH_UPTIME"; else
  s=$(cut -d. -f1 /proc/uptime); up="$((s / 3600))h $((s % 3600 / 60))m"; fi
shell_name="$(basename "${SHELL:-sh}")"

# The orb, drawn with half blocks: two pixels per cell, red and white
# halves, each with a dot of the other colour.
mapfile -t orb < <(awk -v R=10 -v red="224;48;60" -v white="244;238;227" 'BEGIN {
  n = 2 * R
  for (y = 0; y < n; y += 2) {
    line = ""
    for (x = 0; x < n; x++) {
      top = px(x, y); bot = px(x, y + 1)
      if (top == "" && bot == "") line = line " "
      else if (bot == "") line = line "\033[38;2;" top "m\342\226\200\033[0m"
      else if (top == "") line = line "\033[38;2;" bot "m\342\226\204\033[0m"
      else line = line "\033[38;2;" top ";48;2;" bot "m\342\226\200\033[0m"
    }
    print line
  }
}
function px(x, y,   u, v, d, d1, d2, c) {
  u = (x + 0.5 - R) / R; v = (y + 0.5 - R) / R
  d = sqrt(u * u + v * v)
  if (d > 1) return ""
  c = (u > 0) ? red : white
  d1 = sqrt(u * u + (v + 0.5) ^ 2); d2 = sqrt(u * u + (v - 0.5) ^ 2)
  if (d1 < 0.5) c = white
  if (d2 < 0.5) c = red
  if (d1 < 0.16) c = red
  if (d2 < 0.16) c = white
  return c
}')
info=(
""
"${g}${user}${d}@${l}${host}${o}"
"${d}──────────────────${o}"
"${l}OS${o}       ${os}"
"${l}WM${o}       shady · gensokyo"
"${l}Barrier${o}  博麗大結界 · intact"
"${l}Uptime${o}   ${up}"
"${l}Shell${o}    ${shell_name}"
"${l}Donation${o} ¥0 ${d}(as always)${o}"
)
echo
for i in "${!orb[@]}"; do
  printf '  %s   %s\n' "${orb[$i]}" "${info[$i]:-}"
done
printf '\n  %s' "" 
for c in 41 43 42 46 44 45 47; do printf '\e[%sm   \e[0m' "$c"; done
printf '\n\n'
