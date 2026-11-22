#!/usr/bin/env bash
# Logging in, set up with greetd on tty1:
#   - greetd shows a login screen in None's look (tty/greeter, from a copy in /etc/greetd/none,
#     which the greeter user can read): pick None or another installed desktop, then your
#     password. If it can't start, tuigreet (plain text). Logging out comes back to it.
#   - None's lock (sleep, Super+Ctrl+Q) is hyprlock (tty/lock), installed here too.
#   sudo tty/login.sh [MODES]  set it up, or copy changes to it (tty/check.sh says when stale)
#   sudo tty/login.sh undo     back to the login screen you had before
#   tty/login.sh modes         (not root, in a Hyprland session) the monitors' modes as MODES
#   both at once: sudo tty/login.sh "$(tty/login.sh modes)"
# Between desktops the text console shows for a moment: it gets gruver16's colours, no cursor,
# and Hyprland's monitor modes (MODES, as kernel video= options): with Limine as the boot
# loader; with another one the console keeps its own look.
# Arch and its family (pacman).
set -euo pipefail
if [[ ${1:-} == modes ]]; then   # "video=DP-4:2560x1440@200 ..." from the running Hyprland
    # nothing (and no error) without a running Hyprland, e.g. on a text console
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | "video=\(.name):\(.width)x\(.height)@\(.refreshRate | round)"' 2>/dev/null | paste -sd' ' || true
    exit 0
fi
[[ $EUID == 0 && -n ${SUDO_USER:-} ]] || { echo "run with sudo" >&2; exit 1; }
tty=$(dirname "$(readlink -f "$0")")
home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
config=${XDG_CONFIG_HOME:-$home/.config}/none   # yours: machine.lua = monitors and keyboard
sessions=/etc/greetd/sessions
copy=/etc/greetd/none

command -v pacman >/dev/null || { echo "this needs pacman (Arch and its family)" >&2; exit 1; }
# the kernel command line is Limine's to set here (/etc/default/limine, limine-update)
limine() { [[ -f /etc/default/limine ]] && command -v limine-update >/dev/null; }
drop_console_colours() { sed -i -E '/^KERNEL_CMDLINE/s/ (vt\.default_(red|grn|blu)|vt\.global_cursor_default|video)=[^ "]*//g' /etc/default/limine; }
before=/etc/greetd/none-login-before   # the login manager that was enabled before greetd

if [[ ${1:-} == undo ]]; then
    systemctl disable greetd.service
    was=$(cat "$before" 2>/dev/null || echo plasmalogin.service)
    systemctl enable "$was"
    if limine; then drop_console_colours && limine-update; fi
    echo "done: reboot for the login screen you had before ($was)"
    exit 0
fi

pacman -S --needed --noconfirm greetd greetd-tuigreet hyprlock

# None first, then the other desktops installed (/usr/share/wayland-sessions; not the uwsm
# variants, nor None's own entry from tty/session.sh).
rm -rf "$sessions"
mkdir -p "$sessions"
desktop() {  # file, name, command
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n' "$2" "$3" >"$sessions/$1.desktop"
}
# through ~/.local/share/none (tty/install.sh's link) when it leads here: None's folder can move
start=$tty/start
[[ $(readlink -f "$home/.local/share/none/start") == "$start" ]] && start=$home/.local/share/none/start
desktop 1-none None "$start"
n=1
for f in /usr/share/wayland-sessions/*.desktop; do
    [[ -f $f ]] || continue
    id=$(basename "$f" .desktop)
    [[ $id == *uwsm* || $id == none ]] && continue
    name=$(sed -n 's/^Name=//p' "$f" | head -1)
    [[ $id == plasma ]] && name=KDE
    n=$((n + 1))
    desktop "$n-$id" "${name:-$id}" "$(sed -n 's/^Exec=//p' "$f" | head -1)"
done

# the screen's copy (everything readable, nothing writable by the greeter)
rm -rf "$copy"
mkdir -p "$copy"
cp "$tty"/greeter/* "$copy/"
cp -r "$tty/shell" "$copy/shell"
cp "$tty/foot-colors.ini" "$tty/colors.lua" "$copy/"
[[ -f $config/machine.lua ]] && cp -L "$config/machine.lua" "$copy/"
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
if limine; then
    hex=$(sed -nE 's/^(regular|bright)[0-7]=//p' "$tty/foot-colors.ini")
    channel() { echo "$hex" | while read -r h; do printf '%d,' "0x${h:$1:2}"; done | sed 's/,$//'; }
    drop_console_colours
    modes=${1:-}
    # no modes given (no Hyprland to ask): keep the ones already set
    [[ -n $modes ]] || modes=$(grep '^KERNEL_CMDLINE' /etc/default/limine | grep -oE 'video=[^ "]+' | paste -sd' ' || true)
    [[ $modes =~ ^(video=[A-Za-z0-9-]+:[0-9]+x[0-9]+@[0-9]+ ?)*$ ]] || { echo "odd modes: $modes" >&2; exit 1; }
    [[ -n $modes ]] || echo "no monitor modes known: the console keeps its own (inside Hyprland: sudo tty/login.sh \"\$(tty/login.sh modes)\")"
    sed -i -E "/^KERNEL_CMDLINE/s/\"\$/ vt.default_red=$(channel 0) vt.default_grn=$(channel 2) vt.default_blu=$(channel 4) vt.global_cursor_default=0${modes:+ $modes}\"/" /etc/default/limine
    limine-update
else
    echo "no Limine: the text console between desktops keeps its own colours"
fi

# greetd takes over from the login manager enabled now (remembered for `undo`)
dm=/etc/systemd/system/display-manager.service
now=""; [[ -L $dm ]] && now=$(basename "$(readlink -f "$dm")")
if [[ -n $now && $now != greetd.service ]]; then
    echo "$now" >"$before"
    systemctl disable "$now"
fi
systemctl enable greetd.service
echo "done: reboot (or log out) to see it"
