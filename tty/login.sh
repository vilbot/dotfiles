#!/usr/bin/env bash
# Logging in, set up with greetd on tty1:
#   - greetd shows a login screen in None's look (tty/greeter, from a copy in /etc/greetd/none,
#     which the greeter user can read): pick None, Hyprland or KDE, then your password. If it
#     can't start, tuigreet (plain text). Logging out comes back to it.
#   - None's lock (sleep, Super+Ctrl+Q) is hyprlock (tty/lock), installed here too.
#   sudo tty/login.sh [MODES]  set it up, or copy changes to it (tty/check.sh says when stale)
#   sudo tty/login.sh undo     back to Plasma's login screen
#   tty/login.sh modes         (not root, in a Hyprland session) the monitors' modes as MODES
#   ~/run.sh login does both: sudo tty/login.sh "$(tty/login.sh modes)"
# Between desktops the text console shows for a moment: it gets gruver16's colours, no cursor,
# and Hyprland's monitor modes (MODES, as kernel video= options).
set -euo pipefail
if [[ ${1:-} == modes ]]; then   # "video=DP-4:2560x1440@200 ..." from the running Hyprland
    # nothing (and no error) without a running Hyprland, e.g. on a text console
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | "video=\(.name):\(.width)x\(.height)@\(.refreshRate | round)"' 2>/dev/null | paste -sd' ' || true
    exit 0
fi
[[ $EUID == 0 && -n ${SUDO_USER:-} ]] || { echo "run with sudo" >&2; exit 1; }
tty=$(dirname "$(readlink -f "$0")")
dotfiles=$(dirname "$tty")
sessions=/etc/greetd/sessions
copy=/etc/greetd/none

drop_console_colours() { sed -i -E '/^KERNEL_CMDLINE/s/ (vt\.default_(red|grn|blu)|vt\.global_cursor_default|video)=[^ "]*//g' /etc/default/limine; }

if [[ ${1:-} == undo ]]; then
    systemctl disable greetd.service
    systemctl enable plasmalogin.service
    drop_console_colours && limine-update
    echo "done: reboot for Plasma's login screen"
    exit 0
fi

pacman -S --needed --noconfirm greetd greetd-tuigreet hyprlock

# Only these three are listed (not hyprland-uwsm from /usr/share/wayland-sessions).
rm -rf "$sessions"
mkdir -p "$sessions"
desktop() {  # file, name, command
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n' "$2" "$3" >"$sessions/$1.desktop"
}
desktop 1-none     None     "$tty/start"
desktop 2-hyprland Hyprland "$(sed -n 's/^Exec=//p' /usr/share/wayland-sessions/hyprland.desktop)"
desktop 3-kde      KDE      "$(sed -n 's/^Exec=//p' /usr/share/wayland-sessions/plasma.desktop)"

# the screen's copy (everything readable, nothing writable by the greeter)
rm -rf "$copy"
mkdir -p "$copy"
cp "$tty"/greeter/* "$copy/"
cp -r "$tty/shell" "$copy/shell"
cp "$tty/foot-colors.ini" "$dotfiles/hypr/colors.lua" "$dotfiles/hypr/json.lua" "$dotfiles/hypr/settings.json" "$copy/"
sed "s|^include=.*|include=$copy/foot-colors.ini|" "$tty/foot.ini" >"$copy/foot.ini"
chmod -R a+rX,go-w "$copy"
install -d -o greeter -g greeter /var/cache/none-greeter /var/cache/none-greeter/home /var/cache/tuigreet  # what they remember, and a home to write caches in

cat >/etc/greetd/config.toml <<EOF
[terminal]
vt = 1

# the login screen (tty/greeter), at boot and after each logout
# (comments only on their own lines: greetd's reader rejects them after a [section])
[default_session]
command = "bash $copy/greeter.sh"
user = "greeter"
EOF

# console colours = gruver16 (foot-colors.ini's regular0-7, bright0-7), cursor off
hex=$(sed -nE 's/^(regular|bright)[0-7]=//p' "$tty/foot-colors.ini")
channel() { echo "$hex" | while read -r h; do printf '%d,' "0x${h:$1:2}"; done | sed 's/,$//'; }
drop_console_colours
modes=${1:-}
# no modes given (no Hyprland to ask): keep the ones already set
[[ -n $modes ]] || modes=$(grep '^KERNEL_CMDLINE' /etc/default/limine | grep -oE 'video=[^ "]+' | paste -sd' ' || true)
[[ $modes =~ ^(video=[A-Za-z0-9-]+:[0-9]+x[0-9]+@[0-9]+ ?)*$ ]] || { echo "odd modes: $modes" >&2; exit 1; }
[[ -n $modes ]] || echo "no monitor modes known: the console keeps its own (run ~/run.sh login inside Hyprland to set them)"
sed -i -E "/^KERNEL_CMDLINE/s/\"\$/ vt.default_red=$(channel 0) vt.default_grn=$(channel 2) vt.default_blu=$(channel 4) vt.global_cursor_default=0${modes:+ $modes}\"/" /etc/default/limine
limine-update

systemctl disable plasmalogin.service 2>/dev/null || true
systemctl enable greetd.service
echo "done: reboot (or log out) to see it"
