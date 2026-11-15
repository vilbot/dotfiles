#!/usr/bin/env bash
# Keeps a terminal on the "None" desktop (started by tty/hyprland.lua): whenever there are no
# windows, it opens one. Every terminal, this one included, closes like any other window.
# Logging out: `logout` in any terminal (tty/zsh/.zshrc) or Opt+Shift+Esc.
dir=$(dirname "$(readlink -f "$0")")
windows() { hyprctl clients -j 2>/dev/null | grep -c '"address"'; }

while hyprctl version >/dev/null 2>&1; do  # ends with the desktop
    if (( $(windows) == 0 )); then
        "$dir/term" -a tty-session "${SHELL:-zsh}" -l
    else
        sleep 0.5
    fi
done
