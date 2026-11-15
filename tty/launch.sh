#!/usr/bin/env bash
# The "None" desktop's launcher (Cmd+Space): a minibuffer at the top of the screen.
# It opens with the favorites (favorites.txt); typing searches every app. Enter starts the
# picked app, or runs what you typed as a command when nothing matches. Ctrl+F adds or removes
# a favorite. Esc, or Cmd+Space again, closes it.
#   launch.sh            open, or close when it's open
#   launch.sh pick       the picker itself (run inside its terminal)
#   launch.sh list [Q]   favorites when Q is empty, else every app; lines are "name<TAB>id"
#   launch.sh fav ID     add or remove a favorite
#   launch.sh fit N      size the window to the prompt + N results (fzf calls it as results change)
set -uo pipefail
self=$(readlink -f "$0")
dir=$(dirname "$self")
favs=$dir/favorites.txt
font=16 line=25 pad=6 most=12  # Hack size, line height (pt), foot.ini's top/bottom pad (px), max rows

apps() {
    local IFS=:
    local d dirs=("${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share})
    for d in "${dirs[@]}"; do
        [[ -d $d/applications ]] && find -L "$d/applications" -name '*.desktop'
    done | xargs -d '\n' awk -F= '
        FNR == 1 { flush(); id = FILENAME; sub(/.*\/applications\//, "", id); gsub(/\//, "-", id)
                   sub(/\.desktop$/, "", id); name = ""; skip = 0; main = 0 }
        /^\[/ { main = ($0 == "[Desktop Entry]") }
        main && /^Name=/ && name == "" { name = substr($0, 6) }
        main && /^(NoDisplay|Hidden)=true/ { skip = 1 }
        main && /^NotShowIn=.*Hyprland/ { skip = 1 }
        main && /^Type=/ && $2 != "Application" { skip = 1 }
        function flush() { if (id != "" && name != "" && !skip && !seen[id]++) printf "%s\t%s\n", name, id }
        END { flush() }
    ' | awk -F'\t' '!seen[$2]++' | sort -f -u
}

# favorites first, in favorites.txt order, marked with "*"
list() {
    local all; all=$(apps)
    awk -F'\t' -v q="$1" '
        NR == FNR { if ($0 != "") { fav[$0] = ++n }; next }
        $2 in fav { f[fav[$2]] = "* " $1 "\t" $2; next }
        q != "" { rest = rest "  " $0 "\n" }
        END { for (i = 1; i <= n; i++) if (i in f) print f[i]; printf "%s", rest }
    ' "$favs" - <<<"$all"
}

case "${1:-}" in
    "")
        pkill -f -- '^foot .*-a tty-minibuffer' && exit 0
        exec "$dir/term" -a tty-minibuffer -o main.font=Hack:size=$font -o main.line-height=$line "$self" pick
        ;;
    list) list "${2:-}" ;;
    fit)
        # top centre of the focused monitor, half its width; foot's points are 1/72 inch at 96 dpi
        read -r mx my mw scale < <(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.x) \(.y) \(.width) \(.scale)"')
        rows=$(( 1 + (${2:-0} < most ? ${2:-0} : most) ))
        w=$(awk -v w="$mw" -v s="$scale" 'BEGIN { printf "%d", w / s / 2 }')
        h=$(awk -v r="$rows" -v l="$line" -v p="$pad" 'BEGIN { printf "%d", r * int(l * 96 / 72 + 0.5) + 2 * p }')
        win='window = "class:^tty-minibuffer$"'
        hyprctl eval "hl.dispatch(hl.dsp.window.resize({ x = $w, y = $h, $win }))
                      hl.dispatch(hl.dsp.window.move({ x = $((mx + w / 2)), y = $my, $win }))" >/dev/null
        ;;
    fav)
        touch "$favs"
        if grep -qxF -- "$2" "$favs"; then
            grep -vxF -- "$2" "$favs" >"$favs.new"; mv "$favs.new" "$favs"
        else
            echo "$2" >>"$favs"
        fi
        ;;
    pick)
        out=$(list "" | fzf --print-query --delimiter='\t' --with-nth=1 --layout=reverse --no-info \
            --prompt='> ' --pointer='>' --no-separator --no-scrollbar --gutter=' ' \
            --bind "change:reload-sync('$self' list {q})" \
            --bind "result:execute-silent('$self' fit \$FZF_MATCH_COUNT)" \
            --bind "ctrl-f:execute-silent('$self' fav {2})+reload-sync('$self' list {q})" \
            --color='prompt:5,pointer:5,hl:4,hl+:4,bg+:0,gutter:-1')
        query=$(sed -n 1p <<<"$out")
        pick=$(sed -n 2p <<<"$out")
        # Hyprland starts it: whatever this terminal starts itself is killed when the terminal closes.
        run() { hyprctl eval "hl.exec_cmd([==[$1]==])" >/dev/null; }
        if [[ -n $pick ]]; then
            run "gtk-launch ${pick#*$'\t'}"
        elif [[ -n $query ]]; then
            run "$query"
        fi
        ;;
    *) sed -n '2,9p' "$self"; exit 2 ;;
esac
