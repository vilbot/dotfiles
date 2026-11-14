#!/usr/bin/env bash
# While mission control (hymission) is open, keep flag files that others check cheaply:
#   $XDG_RUNTIME_DIR/hymission-open     always: binds.lua (Opt+Tab picks the new desktop's
#                                       leftmost window), Toshy (h/j/k/l and Opt+h/j/k/l move
#                                       the selection)
#   $XDG_RUNTIME_DIR/hymission-search   its search box is up (F4, or / in F3): letters must type
#                                       there, so Toshy only maps Opt+h/j/k/l, to Up/Down
# Started by the F3 / F4 binds (keys/build.py: overview.*) right after they toggle the overview,
# with "plain" or "search"; exits (removing the flags) once the overview has closed.
mode=${1:-plain}
dir=${XDG_RUNTIME_DIR:-/tmp}
open="$dir/hymission-open" search="$dir/hymission-search"

exec 9>"$dir/hymission-flag.lock"
if ! flock -n 9; then         # already watching: just update the mode
    [[ $mode == search ]] && : >"$search" || rm -f "$search"
    exit 0
fi
trap 'rm -f "$open" "$search"' EXIT

: >"$open"
[[ $mode == search ]] && : >"$search" || rm -f "$search"
sleep 0.1
while hyprctl hymission-overview-state 2>/dev/null | grep -q '"active":true'; do
    if [[ $mode == search ]] || hyprctl layers 2>/dev/null | grep -q hymission-search; then
        [[ -e $search ]] || : >"$search"
    else
        rm -f "$search"
    fi
    sleep 0.1
done
