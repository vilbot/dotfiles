# dotfiles

Personal configs for macOS and Windows. **One branch (`main`) for every OS.**
Never create per-OS branches or per-OS copies of a config. Put OS differences inside the file.

## Layout
| Path | App | Linked to (mac / windows) |
|---|---|---|
| `nvim/` | Neovim | `~/.config/nvim` / `%LOCALAPPDATA%\nvim` |
| `wezterm/.wezterm.lua` | WezTerm | `~/.wezterm.lua` (both) |
| `zed/` | Zed | `~/.config/zed/*` / `%APPDATA%\Zed\*` |
| `ghostty/` | Ghostty (mac) | `~/.config/ghostty` |
| `.zshrc` | zsh (mac) | `~/.zshrc` |
| `powershell/` | pwsh 7 (windows) | `$PROFILE` |
| `jetbrains/` | JetBrains theme plugin | installed manually from `jetbrains/gruver16/gruver16-plugin.zip` |
| `theme/` | gruver16 color source + generator | — |
| `nvim_old/` | User's own pre-rewrite nvim config, kept for reference. Don't edit or delete. | — |

`install.sh` (mac) and `install.ps1` (windows) create all links. When adding a new app config, add it to both scripts if it applies.

## OS-specific code
- **nvim:** use `require("config.platform")` (`is_win`, `is_mac`, `is_linux`), never `has("win32")` directly. See `nvim/README.md`.
- **wezterm:** use the `is_win` / `is_mac` locals at the top. Paths go through `dotfiles` (`~/dotfiles`); never hardcode `/Users/...` or `C:\...`.
- **zed:** `settings.json` is shared. Keymaps are split during a transition: `keymap.json` (mac, `cmd-*`) and `keymap.windows.json`. Zed has no per-OS conditionals in keymaps.

## Colors: gruver16
`theme/gruver16.yaml` is the single source of truth. To change a color:
1. Edit `theme/gruver16.yaml` (or `theme/templates/zed.json` for zed-only details like UI alpha values).
2. Run `python3 theme/build.py`, which regenerates the nvim palette, wezterm, ghostty, zed and jetbrains themes.
3. `python3 theme/build.py --check` verifies nothing is out of date.

Do not hand-edit generated files (`nvim/lua/palettes/gruver16.lua`, `wezterm/colors/gruver16.toml`, `ghostty/themes/gruver16`, `zed/themes/gruver16.json`, `jetbrains/gruver16/*`).
`nvim/colors/custom.lua` and `jetbrains/build.py` map palette slots to syntax groups by hand; those are fine to edit.

Terminal quirk: the ANSI "yellow" slot is sage (`base0A`) and ANSI "magenta" is the real yellow (`base0E`). Shells color commands with **magenta** so they show yellow (zsh `fg=magenta`, pwsh `` `e[35m ``).
