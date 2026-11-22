#!/usr/bin/env bash
# Caps Lock = tap Esc, hold Ctrl (tty/keyd.conf), for None, which remaps nothing else: keyd, a
# system service, so it applies in every desktop and on the console too.
#   sudo tty/keys.sh        install keyd, copy the config, start it (again: copy changes)
#   sudo tty/keys.sh undo   stop it (the config stays, unused)
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run with sudo" >&2; exit 1; }
tty=$(dirname "$(readlink -f "$0")")

if [[ ${1:-} == undo ]]; then
    systemctl disable --now keyd.service
    echo "done: Caps Lock is Ctrl again (Hyprland's ctrl:nocaps)"
    exit 0
fi

pacman -S --needed --noconfirm keyd
mkdir -p /etc/keyd
[[ -e /etc/keyd/default.conf && ! -e /etc/keyd/default.conf.orig ]] && cp /etc/keyd/default.conf /etc/keyd/default.conf.orig
install -m 644 -o root -g root "$tty/keyd.conf" /etc/keyd/default.conf
keyd check /etc/keyd/default.conf
systemctl enable keyd.service
systemctl restart keyd.service
echo "done: Caps Lock taps Esc, holds Ctrl"
