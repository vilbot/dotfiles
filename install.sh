#!/usr/bin/env bash
# Symlink dotfiles into place on macOS and Linux. Safe to re-run.
# Existing files that aren't already the right link are moved to <name>.bak-<timestamp>.
#   ./install.sh            link everything
#   ./install.sh --dry-run  show what would happen
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
STAMP="$(date +%Y%m%d-%H%M%S)"

case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)  OS=linux ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

# Zed keymaps: keymap.json is mac (cmd-*). Linux gets keymap.linux.json, generated from it by
# zed/build.py for mackeys' key swaps (Cmd->Ctrl, Ctrl->Super) so Zed behaves like on the Mac.
if [[ $OS == mac ]]; then ZED_KEYMAP=zed/keymap.json; else ZED_KEYMAP=zed/keymap.linux.json; fi

# source (relative to repo)  ->  target
LINKS=(
  ".zshrc                 $HOME/.zshrc"
  "nvim                   $HOME/.config/nvim"
  "ghostty                $HOME/.config/ghostty"
  "zed/settings.json      $HOME/.config/zed/settings.json"
  "$ZED_KEYMAP            $HOME/.config/zed/keymap.json"
  "zed/themes             $HOME/.config/zed/themes"
)
[[ $OS == mac ]] && LINKS+=("wezterm/.wezterm.lua   $HOME/.wezterm.lua")
[[ $OS == linux ]] && LINKS+=(
  "hypr                                       $HOME/.config/hypr"
  "quickshell                                 $HOME/.config/quickshell"
  "kde/env/ghostty-session.sh                 $HOME/.config/plasma-workspace/env/ghostty-session.sh"
  "xdg-desktop-portal/hyprland-portals.conf   $HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
  "keys/daemon/mackeys.service                $HOME/.config/systemd/user/mackeys.service"
  ".zprofile                                  $HOME/.zprofile"
)

run() { if (( DRY )); then echo "  would: $*"; else "$@"; fi; }

for entry in "${LINKS[@]}"; do
  read -r rel target <<<"$entry"
  src="$DOT/$rel"
  if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
    echo "ok      $target"
    continue
  fi
  run mkdir -p "$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    echo "backup  $target -> $target.bak-$STAMP"
    run mv "$target" "$target.bak-$STAMP"
  fi
  echo "link    $target -> $src"
  run ln -s "$src" "$target"
done

# Toshy (mac-style keys on KDE; mackeys does Hyprland) is installed separately; its config is regenerated on upgrade,
# so only our customizations are kept here and written in, not linked.
if [[ $OS == linux ]]; then
  if [[ -f "$HOME/.config/toshy/toshy_config.py" ]]; then
    run python3 "$DOT/toshy/apply.py"
  else
    echo "note    Toshy not installed (https://github.com/RedBearAK/toshy); then re-run to apply toshy/"
  fi
fi

# mackeys (Mac keyboard on Hyprland, keys/daemon): build it; hyprland.lua starts the service.
if [[ $OS == linux ]]; then
  if command -v cargo >/dev/null; then
    run cargo build --release --manifest-path "$DOT/keys/daemon/Cargo.toml"
    run systemctl --user daemon-reload
  else
    echo "note    cargo missing (pacman -S rust); then re-run to build keys/daemon"
  fi
fi

# "None" desktop (tty/): foot draws the console font, turned into a TrueType font here.
if [[ $OS == linux ]]; then
  if ls /usr/share/kbd/consolefonts/ter-v32n.* >/dev/null 2>&1 || grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then
    run python3 "$DOT/tty/psf2ttf.py" && run fc-cache -f "$HOME/.local/share/fonts"
  else
    echo "note    terminus-font missing (pacman -S terminus-font foot yazi); then re-run for tty/"
  fi
fi

# Hide apps listed in hypr/hidden-apps.txt on Hyprland (overrides in ~/.local/share/applications).
[[ $OS == linux ]] && run python3 "$DOT/hypr/hide-apps.py"

# Login shell should be zsh. chsh asks for a password, so only print the command.
if [[ $OS == linux ]]; then
  login_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$(basename "$login_shell")" != zsh ]]; then
    echo "note    login shell is $login_shell; switch with: chsh -s $(command -v zsh)"
  fi
fi
