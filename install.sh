#!/usr/bin/env bash
# Symlink dotfiles into place on macOS. Safe to re-run.
# Existing files that aren't already the right link are moved to <name>.bak-<timestamp>.
#   ./install.sh            link everything
#   ./install.sh --dry-run  show what would happen
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
STAMP="$(date +%Y%m%d-%H%M%S)"

# source (relative to repo)  ->  target
LINKS=(
  ".zshrc                 $HOME/.zshrc"
  "wezterm/.wezterm.lua   $HOME/.wezterm.lua"
  "nvim                   $HOME/.config/nvim"
  "ghostty                $HOME/.config/ghostty"
  "zed/settings.json      $HOME/.config/zed/settings.json"
  "zed/keymap.json        $HOME/.config/zed/keymap.json"
  "zed/themes             $HOME/.config/zed/themes"
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
