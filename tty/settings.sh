#!/usr/bin/env bash
# Opens None's Settings app (tty/settings) at PAGE (shortcuts, appearance, input), or brings the
# open one forward at that page.   settings.sh [PAGE]
dir="$(dirname "$(readlink -f "$0")")/settings"
if qs -p "$dir" ipc call settings open "${1:-}" >/dev/null 2>&1; then
    hyprctl dispatch 'hl.dsp.focus({ window = "class:^none-settings$" })' >/dev/null
else
    NONE_SETTINGS_PAGE="${1:-}" exec qs -p "$dir" -n -d
fi
