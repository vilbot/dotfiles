#!/usr/bin/env bash
# A "None" entry for the login screen you already have (SDDM, GDM, Plasma's, ...): it starts
# tty/start. Not needed with None's own login screen (tty/login.sh), which lists None itself.
#   sudo tty/session.sh        add it
#   sudo tty/session.sh undo   take it away
set -euo pipefail
[[ $EUID == 0 && -n ${SUDO_USER:-} ]] || { echo "run with sudo" >&2; exit 1; }
tty=$(dirname "$(readlink -f "$0")")
entry=/usr/share/wayland-sessions/none.desktop

if [[ ${1:-} == undo ]]; then
    rm -f "$entry"
    echo "done: no None entry"
    exit 0
fi

# through ~/.local/share/none (tty/install.sh's link) when it leads here: None's folder can move
home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
start=$tty/start
[[ $(readlink -f "$home/.local/share/none/start") == "$start" ]] && start=$home/.local/share/none/start
mkdir -p "$(dirname "$entry")"
printf '[Desktop Entry]\nType=Application\nName=None\nComment=An all-terminal desktop\nExec=%s\n' "$start" >"$entry"
echo "done: pick None when you log in"
