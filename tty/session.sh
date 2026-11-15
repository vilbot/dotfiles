#!/usr/bin/env bash
# The "None" desktop's session terminal, i.e. the console (started by tty/hyprland.lua).
# Logging out = the shell ending by itself (exit, logout, Ctrl+D): the desktop ends and you're
# back at the login prompt. Closing the window (Cmd+Q) only closes it: a new one opens, like a
# console that always has a login on it.
dir=$(dirname "$(readlink -f "$0")")
done=${XDG_RUNTIME_DIR:-/tmp}/tty-session-$$.logout
rm -f "$done"
while :; do
    # the marker is only written when the shell ends on its own; closing the window kills both
    "$dir/term" -a tty-session sh -c "\"\${SHELL:-zsh}\" -l; touch '$done'"
    [[ -e $done ]] && break
    hyprctl version >/dev/null 2>&1 || exit 0  # the desktop itself is gone
done
rm -f "$done"
hyprctl eval 'hl.dispatch(hl.dsp.exit())'
