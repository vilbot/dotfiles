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

# Zed keymaps: keymap.json is mac (cmd-*). Linux uses the same ctrl-based keymap as Windows.
if [[ $OS == mac ]]; then ZED_KEYMAP=zed/keymap.json; else ZED_KEYMAP=zed/keymap.windows.json; fi

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

# Login shell should be zsh. chsh asks for a password, so only print the command.
if [[ $OS == linux ]]; then
  login_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$(basename "$login_shell")" != zsh ]]; then
    echo "note    login shell is $login_shell; switch with: chsh -s $(command -v zsh)"
  fi
fi
