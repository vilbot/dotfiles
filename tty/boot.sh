#!/usr/bin/env bash
# The boot between Limine and the login: one screen, None's gray with a gruver16 wave (Plymouth
# theme "none", tty/boot/plymouth.py), no text; it stays up until None draws its first frame. And
# Limine's menu in gruver16 (tty/boot/limine.py).
#   sudo tty/boot.sh        set it up (again, after changing the theme)
#   sudo tty/boot.sh undo   back to CachyOS's splash and Limine's own colours
set -euo pipefail
[[ $EUID == 0 ]] || { echo "run with sudo" >&2; exit 1; }
tty=$(dirname "$(readlink -f "$0")")
conf=/boot/limine.conf
dropin=/etc/systemd/system/plymouth-quit.service.d/none.conf
# NVIDIA in the initramfs (early KMS): Plymouth won't draw on the firmware's basic display and
# waits for a real driver; loaded from disk, NVIDIA's arrives only a second before the login
early=/etc/mkinitcpio.conf.d/90-none-nvidia-early.conf
# an earlier version's greetd drop-in (cleared tty1; not needed), removed when found
old_blank=/etc/systemd/system/greetd.service.d/none-blank-tty1.conf
# splash: Plymouth draws; the rest keeps the kernel and systemd from printing over it
quiet="splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false"
drop_quiet() {
    sed -i -E '/^KERNEL_CMDLINE/s/ (splash|loglevel=[0-9]+|rd\.udev\.log_level=[0-9]+|(rd\.)?systemd\.show_status=[a-z]+)//g' /etc/default/limine
}

if [[ ${1:-} == undo ]]; then
    drop_quiet
    rm -f "$dropin" "$early" "$old_blank"; systemctl daemon-reload
    plymouth-set-default-theme cachyos
    python3 "$tty/boot/limine.py" "$conf" --remove
    limine-mkinitcpio
    echo "done: reboot"
    exit 0
fi

python3 "$tty/boot/plymouth.py" /usr/share/plymouth/themes/none
plymouth-set-default-theme none
drop_quiet
sed -i -E "/^KERNEL_CMDLINE/s/\"\$/ $quiet\"/" /etc/default/limine

printf '# tty/boot.sh: NVIDIA loads in the initramfs, so the boot splash has a display early\nMODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n' >"$early"

# Plymouth's last frame stays on screen until the next program draws (None, behind its lock),
# instead of a black screen in between. (Nothing may print to tty1 after it, or the kernel's
# console takes over the screen and shows boot text: tty/desktops sends its output elsewhere.)
mkdir -p "$(dirname "$dropin")"
cat >"$dropin" <<'UNIT'
[Service]
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
UNIT
rm -f "$old_blank"
systemctl daemon-reload

limine-mkinitcpio   # the initramfs (now with the theme) and the boot entries, checksums included
[[ -f $conf.before-none ]] || cp "$conf" "$conf.before-none"   # a copy from before, just in case
python3 "$tty/boot/limine.py" "$conf"
echo "done: reboot"
