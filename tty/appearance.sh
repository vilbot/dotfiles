#!/usr/bin/env bash
# Dark / light mode for the apps that aren't terminals (None's appearance.toggle, and tty/theme.py
# when the theme's variant changes):
#   appearance.sh toggle | dark | light | get
# - GTK 4 / libadwaita apps, Chrome (its Mode set to "Device") and websites, and anything else
#   reading the desktop portal's color-scheme: gsettings org.gnome.desktop.interface color-scheme
# - GTK 3 apps: gtk-theme Breeze / Breeze-Dark (when installed)
# - Qt / KDE apps: the KDE color scheme BreezeLight / BreezeDark (when Plasma's tools are installed)
set -euo pipefail

current=$(gsettings get org.gnome.desktop.interface color-scheme)
is_dark() { [[ $current == "'prefer-dark'" ]]; }

case "${1:-toggle}" in
    get)    is_dark && echo dark || echo light; exit 0 ;;
    dark)   mode=dark ;;
    light)  mode=light ;;
    toggle) is_dark && mode=light || mode=dark ;;
    *)      echo "usage: ${0##*/} toggle|dark|light|get" >&2; exit 64 ;;
esac

if [[ $mode == dark ]]; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme Breeze-Dark
    scheme=BreezeDark
else
    gsettings set org.gnome.desktop.interface color-scheme prefer-light
    gsettings set org.gnome.desktop.interface gtk-theme Breeze
    scheme=BreezeLight
fi
# (says so and exits 1 when the scheme is already set)
if command -v plasma-apply-colorscheme >/dev/null; then
    plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 || true
fi
