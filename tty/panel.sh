#!/usr/bin/env bash
# The "None" desktop's settings panel (F5, or "Settings" in the launcher): a terminal down the
# right side, over the windows, with tabs for sound, bluetooth and network (what each shows and
# does: tty/panel/panel.py). Same keys on every tab: j/k move, H/L (or Tab, or a click on the tab
# line) switch tabs, q or Esc close; the tab's own keys are in the lines at the bottom, and a
# click on one of those hints does what its key does.
#   panel.sh            open, or close when it's open
#   panel.sh run        the panel itself, inside its terminal
#   panel.sh close      close it (sliding out)
set -uo pipefail
self=$(readlink -f "$0")
dir=$(dirname "$self")
py=$dir/panel/panel.py
# Closing slides it out first: Hyprland's own closing animation can't show a foot window (it
# keeps only the border; foot's contents are gone the moment it closes), but a move animates.
close() {
    local win='window = "class:^tty-panel$"' w
    w=$(hyprctl clients -j | jq -r '.[] | select(.class == "tty-panel") | .size[0]' | head -1)
    [[ -n $w ]] || return 0
    hyprctl dispatch "hl.dsp.window.move({ x = $w, y = 0, relative = true, $win })" >/dev/null
    sleep 0.15   # the move's length (tty/hyprland.lua: 140ms)
    hyprctl dispatch "hl.dsp.window.close({ $win })" >/dev/null
}

case "${1:-}" in
    "")
        if pgrep -f -- '^foot .*-a tty-panel' >/dev/null; then close; exit 0; fi
        exec "$dir/term" -a tty-panel "$self" run
        ;;
    run)
        binds=(
            "j:down,k:up,g:first,G:last"
            "q:execute-silent('$self' close),esc:execute-silent('$self' close)"
            "H:transform('$py' go -1),shift-tab:transform('$py' go -1)"
            "L:transform('$py' go +1),tab:transform('$py' go +1)"
            "click-header:transform:[[ -n \$FZF_CLICK_HEADER_WORD ]] && '$py' go \$FZF_CLICK_HEADER_WORD"
            "every(1):reload-sync('$py' list)"
            "double-click:transform('$py' on enter {2})"
            "click-footer:transform('$py' click \$FZF_CLICK_FOOTER_LINE \$FZF_CLICK_FOOTER_COLUMN {2})"
        )
        for key in $("$py" keys); do binds+=("$key:transform('$py' on $key {2})"); done
        args=(); for b in "${binds[@]}"; do args+=(--bind "$b"); done
        "$py" list | fzf --ansi --no-input --layout=reverse --no-info --no-separator --no-scrollbar \
            --delimiter='\t' --with-nth=1 --track --id-nth=2 \
            --pointer='>' --gutter=' ' --header-first \
            --header="$("$py" header)" --footer="$("$py" footer)" \
            --color='pointer:5,bg+:0,gutter:-1' \
            "${args[@]}" >/dev/null
        ;;
    close) close ;;
    *) sed -n '2,7p' "$self"; exit 2 ;;
esac
