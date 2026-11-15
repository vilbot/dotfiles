#!/usr/bin/env bash
# The "None" desktop's launcher (Cmd+Space), shown as a minibuffer along the bottom of the screen.
# Type to filter the installed apps; Enter starts the picked app, or runs what you typed as a
# command when nothing matches. Esc closes.
set -uo pipefail

apps() {
    local IFS=:
    local dirs=("${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share})
    for d in "${dirs[@]}"; do
        [[ -d $d/applications ]] && find -L "$d/applications" -name '*.desktop' -printf '%P\t%p\n'
    done | awk -F'\t' '!seen[$1]++' | while IFS=$'\t' read -r rel path; do
        awk -v id="${rel//\//-}" -F= '
            /^\[/ { main = ($0 == "[Desktop Entry]") }
            main && /^Name=/ && !name { name = substr($0, 6) }
            main && /^(NoDisplay|Hidden)=true/ { skip = 1 }
            main && /^NotShowIn=.*Hyprland/ { skip = 1 }
            main && /^Type=/ && $2 != "Application" { skip = 1 }
            END { if (name && !skip) printf "%s\t%s\n", name, substr(id, 1, length(id) - 8) }
        ' "$path"
    done | sort -f -u
}

out=$(apps | fzf --print-query --delimiter='\t' --with-nth=1 --layout=reverse --no-info \
    --prompt='> ' --pointer='>' --no-separator --no-scrollbar \
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
