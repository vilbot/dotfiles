#!/usr/bin/env bash
# The login screen: greetd + tuigreet on tty1. Pick None, Hyprland or KDE with F3, log in;
# it remembers your last desktop. Logging out of a desktop brings it back.
#   sudo tty/login.sh        set it up (again): packages, /etc/greetd, the three desktops
#   sudo tty/login.sh undo   back to Plasma's login screen
set -euo pipefail
[[ $EUID == 0 && -n ${SUDO_USER:-} ]] || { echo "run with sudo" >&2; exit 1; }
tty=$(dirname "$(readlink -f "$0")")
sessions=/etc/greetd/sessions

if [[ ${1:-} == undo ]]; then
    systemctl disable greetd.service
    systemctl enable plasmalogin.service
    echo "done: reboot for Plasma's login screen"
    exit 0
fi

pacman -S --needed --noconfirm greetd greetd-tuigreet

# Only these three are listed (not hyprland-uwsm from /usr/share/wayland-sessions).
rm -rf "$sessions"
mkdir -p "$sessions"
desktop() {  # file, name, command
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n' "$2" "$3" >"$sessions/$1.desktop"
}
desktop 1-none     None     "$tty/start"
desktop 2-hyprland Hyprland "$(sed -n 's/^Exec=//p' /usr/share/wayland-sessions/hyprland.desktop)"
desktop 3-kde      KDE      "$(sed -n 's/^Exec=//p' /usr/share/wayland-sessions/plasma.desktop)"

cat >/etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --asterisks --remember --remember-user-session --sessions $sessions"
user = "greeter"
EOF
install -d -o greeter -g greeter /var/cache/tuigreet  # where --remember keeps its memory

systemctl disable plasmalogin.service 2>/dev/null || true
systemctl enable greetd.service
echo "done: reboot (or: sudo systemctl start greetd from a text console)"
