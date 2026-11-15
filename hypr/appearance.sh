#!/usr/bin/env bash
# Dark / light mode for everything at once (F6, keys/remap.toml: appearance.toggle):
#   appearance.sh toggle | dark | light | get
# - GTK 4 / libadwaita apps, Chrome (its Mode set to "Device") and websites, and anything else
#   reading the desktop portal's color-scheme: gsettings org.gnome.desktop.interface color-scheme
#   (xdg-desktop-portal-gtk passes it on; apps switch while running)
# - GTK 3 apps: gtk-theme Breeze / Breeze-Dark
# - Qt / KDE apps: the KDE color scheme BreezeLight / BreezeDark (kdeglobals, applied live)
# - Quickshell (bar, panels) follows the gsettings value itself (quickshell/services/Theme.qml)
# - liquid glass (hyprglass): its dark / light theme
# Ghostty, Zed and nvim keep gruver16 (dark) either way.
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
plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 || true
# liquid glass (hyprglass plugin, set up in hyprland.lua): its light or dark look
hyprctl eval "if hl.plugin.hyprglass then hl.plugin.hyprglass.config({ default_theme = \"$mode\" }) end" \
    >/dev/null 2>&1 || true
