#!/usr/bin/env bash
# Sets None up for you, without sudo. Safe to run again.
#   - says which packages are missing (Arch and its family)
#   - builds caret (the keyboard layout at the text cursor)
#   - ~/.local/share/none -> this folder: the one path everything outside None uses (the login
#     screen's entry, hooks), so the folder can move: run this again from the new place
#   - ~/.config/none: your own files, made from defaults/ where they're missing
# Then, to log in to it, one of (each needs sudo, each has `undo`):
#   sudo ./session.sh   a "None" entry in the login screen you already have
#   sudo ./login.sh     None's own login screen (greetd)
# And if you like:  sudo ./keys.sh (Caps Lock: tap Esc, hold Ctrl),  sudo ./boot.sh (boot screen)
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
config=${XDG_CONFIG_HOME:-$HOME/.config}/none
share=${XDG_DATA_HOME:-$HOME/.local/share}/none

# ---- packages ---------------------------------------------------------------------------------
need=(hyprland quickshell foot hypridle hyprlock ttf-hack python jq fzf curl sqlite gtk3 libnotify
      wireplumber libpulse playerctl networkmanager bluez-utils grim slurp wl-clipboard rust)
# what works without them: Files (yazi), Neovim, the update tab (arch-update), screen
# brightness (ddcutil, or hyprsunset to dim), websites in the launcher (google-chrome, AUR)
optional=(yazi nvim arch-update ddcutil hyprsunset)   # by their commands
if command -v pacman >/dev/null; then
    missing=(); for p in "${need[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
    extra=(); for p in "${optional[@]}"; do command -v "$p" >/dev/null || extra+=("$p"); done
    if (( ${#missing[@]} )); then echo "missing  sudo pacman -S --needed ${missing[*]}"; else echo "ok       packages"; fi
    (( ${#extra[@]} )) && echo "note     optional, not installed: ${extra[*]}"
else
    echo "note     no pacman: None is made for Arch and its family; it needs ${need[*]}"
fi

# ---- caret ------------------------------------------------------------------------------------
if command -v cargo >/dev/null; then
    cargo build --release --quiet --manifest-path "$here/caret/Cargo.toml" && echo "ok       caret built"
else
    echo "missing  cargo (the rust package): caret isn't built, so the keyboard layout shows only in the corner"
fi

# ---- the link ---------------------------------------------------------------------------------
mkdir -p "$(dirname "$share")"
if [[ -L $share || ! -e $share ]]; then
    ln -sfn "$here" "$share" && echo "ok       $share -> $here"
else
    echo "note     $share is in the way (not a link): left alone"
fi

# ---- yours ------------------------------------------------------------------------------------
mkdir -p "$config"
for f in "$here"/defaults/*; do
    [[ -e $config/$(basename "$f") ]] || { cp "$f" "$config/" && echo "new      $config/$(basename "$f")"; }
done
echo "ok       $config"

python3 "$here/theme.py" ensure
[[ ${XDG_CURRENT_DESKTOP:-} == Hyprland && -n ${NONE_THEME:-} ]] || echo "next     sudo $here/session.sh  (or login.sh), then pick None when you log in"
