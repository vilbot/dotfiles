#!/usr/bin/env bash
# Screenshot of an area you drag (Esc cancels). Bound to the keyboard's screenshot key
# (keys/keymap.toml: screenshot.region). Saves to ~/Pictures/Screenshots, copies the picture to
# the clipboard (needs wl-copy, from the wl-clipboard package) and shows a notification with it.
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot $(date '+%Y-%m-%d at %H.%M.%S').png"

# the rest of the screen dims, the area stays clear with a paper-white outline, so it shows on
# dark and light backgrounds alike; cancelled -> no screenshot
geom=$(slurp -d -b '#00000059' -c '#f3efe6ff' -s '#00000000' -w 2) || exit 0
grim -g "$geom" "$file"

if command -v wl-copy >/dev/null; then
    wl-copy --type image/png < "$file"
    copied=" · copied"
else
    copied=""
fi
notify-send -a Screenshot -i "$file" "Screenshot saved" "${file##*/}$copied"
