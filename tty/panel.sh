#!/usr/bin/env bash
# The "None" desktop's settings panel (F5): a terminal down the right side, over the windows,
# with tabs for sound, bluetooth and network (what each shows and does: tty/panel/panel.py).
# Same keys on every tab: j/k move, H/L (or Tab, or a click on the tab line) switch tabs,
# q or Esc close; the tab's own keys are in the line at the bottom. F5 again also closes it.
#   panel.sh            open, or close when it's open
#   panel.sh tab [TAB]  show TAB (default: the last one), inside the panel's terminal
set -uo pipefail
self=$(readlink -f "$0")
dir=$(dirname "$self")
py=$dir/panel/panel.py
tabs=(sound bluetooth network)
last=${XDG_RUNTIME_DIR:-/tmp}/tty-panel-tab

case "${1:-}" in
    "")
        pkill -f -- '^foot .*-a tty-panel' && exit 0
        exec "$dir/term" -a tty-panel "$self" tab
        ;;
    tab)
        tab=${2:-$(cat "$last" 2>/dev/null)}
        [[ " ${tabs[*]} " == *" $tab "* ]] || tab=${tabs[0]}
        echo "$tab" >"$last"
        for i in "${!tabs[@]}"; do [[ ${tabs[i]} == "$tab" ]] && n=$i; done
        prev=${tabs[(n + ${#tabs[@]} - 1) % ${#tabs[@]}]}
        next=${tabs[(n + 1) % ${#tabs[@]}]}

        list="'$py' list $tab"
        binds=(
            "j:down,k:up,g:first,G:last,q:abort,esc:abort"
            "H:become('$self' tab $prev),shift-tab:become('$self' tab $prev)"
            "L:become('$self' tab $next),tab:become('$self' tab $next)"
            "click-header:transform:[[ -n \$FZF_CLICK_HEADER_WORD ]] && echo \"become('$self' tab \$FZF_CLICK_HEADER_WORD)\""
            "every(1):reload-sync:$list"
        )
        # the tab's own keys: "name key method" from panel.py; asking ones get the terminal
        while read -r name key method; do
            run=execute-silent; [[ $method == ask* ]] && run=execute
            binds+=("$key:$run('$py' do $tab $name {2})+reload-sync:$list")
            [[ $key == enter ]] && binds+=("double-click:$run('$py' do $tab $name {2})+reload-sync:$list")
        done < <(python3 "$py" binds "$tab")
        bind_args=(); for b in "${binds[@]}"; do bind_args+=(--bind "$b"); done
        eval "$list" | fzf --ansi --no-input --layout=reverse --no-info --no-separator --no-scrollbar \
            --delimiter='\t' --with-nth=1 --track --id-nth=2 \
            --pointer='>' --gutter=' ' --header-first \
            --header="$(python3 "$py" tabs "$tab")"$'\n ' \
            --footer="$(python3 "$py" keys "$tab")" \
            --color='pointer:5,bg+:0,gutter:-1' \
            "${bind_args[@]}" >/dev/null
        ;;
    *) sed -n '2,7p' "$self"; exit 2 ;;
esac
