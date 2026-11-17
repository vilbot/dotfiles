#!/usr/bin/env bash
# The "None" desktop's settings panel (F5, or "Settings" in the launcher): a terminal down the
# right side, over the windows, with tabs for sound, bluetooth, network, update, theme and help
# (what each shows and does: tty/panel/panel.py). Same keys on every tab: j/k move, H/L (or Tab, or a click on the tab
# line) switch tabs, q or Esc close; the tab's own keys are in the lines at the bottom, and a
# click on one of those hints does what its key does.
#   panel.sh            open, or close when it's open
#   panel.sh TAB        open on TAB (the bar's icons); close when it's open on TAB already
#   panel.sh open TAB   open on TAB, or switch to it (never closes)
#   panel.sh run        the panel itself, inside its terminal
#   panel.sh close      close it (sliding out)
set -uo pipefail
self=$(readlink -f "$0")
dir=$(dirname "$self")
py=$dir/panel/panel.py
run=${XDG_RUNTIME_DIR:-/tmp}
tabfile=$run/tty-panel-tab
# the list tabs' fzf takes actions here, so a tab can be switched from outside (panel.sh TAB)
sock=$run/tty-panel-fzf.sock
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

is_open() { pgrep -f -- '^foot .*-a tty-panel' >/dev/null; }

case "${1:-}" in
    "")
        if is_open; then close; exit 0; fi
        exec "$dir/term" -a tty-panel "$self" run
        ;;
    sound|bluetooth|network|update|theme|help)
        is_open && [[ $(cat "$tabfile" 2>/dev/null) == "$1" ]] && { close; exit 0; }
        exec "$self" open "$1"
        ;;
    open)
        if is_open; then
            # a list tab switches in place; help and the update's own view are programs of their
            # own (no socket): the panel opens again, on the tab
            curl -sf --unix-socket "$sock" -X POST http://localhost -d "transform('$py' go $2)" && exit 0
            close
            for _ in {1..40}; do is_open || break; sleep 0.05; done
        fi
        echo "$2" >"$tabfile"
        exec "$dir/term" -a tty-panel "$self" run
        ;;
    run)
        tab=$(cat "$tabfile" 2>/dev/null)
        # the help tab is its own program (keys and the support chat), and so is the update tab while
        # an update runs (or until you've seen how it ended); they come back here for the others
        [[ $tab == help ]] && exec "$dir/panel/help.py"
        [[ $tab == update ]] && "$dir/panel/update.py" active && exec "$dir/panel/update.py" attach
        binds=(
            "g:first,G:last"
            # once the list is in: the cursor where the tab wants it (the theme tab: on the current theme)
            "load:transform('$py' landed)+unbind(load)"
            "q:execute-silent('$self' close),esc:execute-silent('$self' close)"
            "H:transform('$py' go -1),shift-tab:transform('$py' go -1)"
            "L:transform('$py' go +1),tab:transform('$py' go +1)"
            "click-header:transform('$py' tab-at \$FZF_CLICK_HEADER_COLUMN)"
            # the list again every second, built in the background so keys and clicks never wait
            "every(1):bg-transform('$py' refresh)"
            "double-click:transform('$py' on enter {2})"
            "click-footer:transform('$py' click \$FZF_CLICK_FOOTER_LINE \$FZF_CLICK_FOOTER_COLUMN {2})"
        )
        # moving: on the theme tab, moving onto a theme switches to it (panel.py moved); the check
        # is in the shell so the other tabs don't wait for Python on every j/k
        # (`transform:` takes the rest of the bind, parentheses and all: one bind per key)
        for key in j:down k:up down:down up:up; do
            binds+=("$key+transform:[ \"\$(cat '$tabfile')\" = theme ] && '$py' moved {2} || true")
        done
        for key in $("$py" keys); do binds+=("$key:transform('$py' on $key {2})"); done
        args=(); for b in "${binds[@]}"; do args+=(--bind "$b"); done
        "$py" list | fzf --ansi --no-input --layout=reverse --no-info --no-separator --no-scrollbar \
            --delimiter='\t' --with-nth=1 --track --id-nth=2 \
            --pointer='>' --gutter=' ' --header-first \
            --header="$("$py" header)" --footer="$("$py" footer)" \
            --color='16,pointer:5,bg+:0,fg+:7,gutter:-1' --listen="$sock" \
            "${args[@]}" >/dev/null
        ;;
    close) close ;;
    *) sed -n '2,7p' "$self"; exit 2 ;;
esac
