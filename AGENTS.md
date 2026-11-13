# dotfiles

Personal configs for macOS, Linux (CachyOS) and Windows. **One branch (`main`) for every OS.**
Never create per-OS branches or per-OS copies of a config. Put OS differences inside the file.

## Layout
| Path | App | Linked to (mac + linux / windows) |
|---|---|---|
| `nvim/` | Neovim | `~/.config/nvim` / `%LOCALAPPDATA%\nvim` |
| `wezterm/.wezterm.lua` | WezTerm (mac, windows) | `~/.wezterm.lua` |
| `zed/` | Zed | `~/.config/zed/*` / `%APPDATA%\Zed\*` |
| `ghostty/` | Ghostty (mac, linux) | `~/.config/ghostty` |
| `.zshrc` | zsh (mac, linux) | `~/.zshrc` |
| `powershell/` | pwsh 7 (windows) | `$PROFILE` |
| `jetbrains/` | JetBrains theme plugin | installed manually from `jetbrains/gruver16/gruver16-plugin.zip` |
| `theme/` | gruver16 color source + generator | — |
| `keys/` | desktop/WM keybind source + generator (KDE + Hyprland) | KDE: `keys/build.py --apply`; Hyprland: generates `hypr/binds.lua` |
| `toshy/` | Toshy (linux) customizations: config slices + tray preferences | written into `~/.config/toshy` by `toshy/apply.py` |
| `hypr/` | Hyprland (linux): `hyprland.lua` + modules (`binds.lua`, `colors.lua` generated; `settings.lua` written by the settings app), `hidden-apps.txt` | `~/.config/hypr` (linux) |
| `xdg-desktop-portal/` | portal backends for Hyprland (KDE file picker) | `~/.config/xdg-desktop-portal/` (linux) |
| `quickshell/` | Quickshell (linux, Hyprland): bar, wallpaper, notifications, control center, settings window, command palette, Opt+? keybind sheet; `Colors.qml` and `KeybindsData.qml` generated | `~/.config/quickshell` (linux) |
| `kde/env/` | Plasma login scripts | `~/.config/plasma-workspace/env/` (linux) |
| `nvim_old/` | User's own pre-rewrite nvim config, kept for reference. Don't edit or delete. | — |

`install.sh` (mac and linux) and `install.ps1` (windows) create all links. When adding a new app config, add it to both scripts if it applies.

## OS-specific code
- **nvim:** use `require("config.platform")` (`is_win`, `is_mac`, `is_linux`), never `has("win32")` directly. See `nvim/README.md`.
- **zsh:** branch on `is_mac` at the top of `.zshrc`. Linux plugins come from `/usr/share/zsh/plugins` (pacman), mac ones from brew.
- **ghostty:** reference themes by name (`theme = gruver16`), never by absolute path. Per-desktop differences go in `ghostty/<desktop>.ghostty`, loaded through the gitignored `session.ghostty` link: Hyprland links it to `hyprland.ghostty` at startup, `kde/env/ghostty-session.sh` removes it at Plasma login.
- **wezterm:** use the `is_win` / `is_mac` locals at the top. Paths go through `dotfiles` (`~/dotfiles`); never hardcode `/Users/...` or `C:\...`.
- **zed:** `settings.json` is shared. `keymap.json` is the Mac keymap and the source of truth. Linux links the generated `keymap.linux.json` (`python3 zed/build.py`, `--check`): it unbinds Zed's Linux defaults and rebinds the Mac defaults (`zed/upstream/`, refresh on Zed upgrades) + `keymap.json`, translated for Toshy (cmd→ctrl, ctrl→super). Toshy passes Zed's keys through unchanged (`toshy/slices/user_apps.py`). Windows still uses the hand-written `keymap.windows.json`.

## Colors: gruver16
`theme/gruver16.yaml` is the single source of truth. To change a color:
1. Edit `theme/gruver16.yaml` (or `theme/templates/zed.json` for zed-only details like UI alpha values).
2. Run `python3 theme/build.py`, which regenerates the nvim palette, wezterm, ghostty, zed and jetbrains themes.
3. `python3 theme/build.py --check` verifies nothing is out of date.

Do not hand-edit generated files (`nvim/lua/palettes/gruver16.lua`, `wezterm/colors/gruver16.toml`, `ghostty/themes/gruver16`, `zed/themes/gruver16.json`, `jetbrains/gruver16/*`).
`nvim/colors/custom.lua` and `jetbrains/build.py` map palette slots to syntax groups by hand; those are fine to edit.

## Keybinds
`keys/keymap.toml` is the single source of truth for desktop / window-manager shortcuts (desktops, launcher, layout switching).
Keys are written as physical Mac-keyboard keys (`cmd`, `opt`, `ctrl`, `shift`); `keys/build.py` translates them per platform.
On Linux, Toshy remaps keys first: cmd → Ctrl, opt → Alt, ctrl → Super (Ctrl in terminals).
1. Edit `keys/keymap.toml`.
2. Run `python3 keys/build.py --apply` (regenerates `keys/generated/*` and writes KDE's config; log out/in after). `--check` verifies nothing is stale.

Do not hand-edit `keys/generated/*`, `hypr/binds.lua` or `quickshell/KeybindsData.qml`. A new action needs an entry in `HYPR_ACTIONS` and/or `KDE_ACTIONS` and a label in `SHEET` (the Opt+? cheat sheet; the build fails without one).

## Toshy (linux)
Installed separately; its installer regenerates `~/.config/toshy/toshy_config.py` on upgrade, keeping only the `SLICE_MARK_START/END` sections. So never link or copy the whole file:
- `toshy/slices/<slice>.py` is the body of that slice; `toshy/preferences.toml` holds tray-menu settings (sqlite prefs).
- `python3 toshy/apply.py` writes both in and restarts Toshy; `--check` reports differences.
- Changed something in the tray or the live config? Copy it back into `toshy/` so the repo stays the source.
- keyd is not used: it conflicts with Toshy (both grab keyboards). Caps → Esc/Ctrl is Toshy's `capslock_mode`.

## Hyprland (linux)
- Config is **Lua** (`hypr/hyprland.lua`, Hyprland 0.53+), not hyprlang `.conf`. API stubs: `/usr/share/hypr/stubs/hl.meta.lua`.
- Modules are loaded with `require`: `binds.lua` (generated by `keys/build.py`), `colors.lua` (generated by `theme/build.py`), `kde.lua` (KDE app integration).
- Always run `Hyprland --verify-config -c hypr/hyprland.lua` after editing; it checks dispatcher arguments too.
- Keybinds come from `keys/keymap.toml`. Opt (ALT after Toshy) is the window-management modifier. Cmd+Space reaches Hyprland as SUPER+F13 (set in `toshy/slices/user_apps.py`; Toshy's default SUPER+D collides with physical Ctrl+D).
- Launchers: `programs.launcher` (Cmd+Space, the Quickshell command palette `quickshell/CommandPalette.qml`) / `programs.launcher_alt` (Cmd+Opt+Space, Vicinae as backup) in `hyprland.lua`.
- The Sony TV mirrors the Samsung (monitor rule in `hyprland.lua`).
- `settings.lua` is written by the Quickshell settings window (`quickshell/Settings.qml`: Hyprland options + monitor modes) and applied last in `hyprland.lua`. Changing an option there overrides the value in `hyprland.lua`; per-monitor modes live only there. Keep its one-entry-per-line format (the app parses it back).
- Control center (`quickshell/ControlCenter.qml`, the switches icon in the bar): sound, brightness (ddcutil; needs DDC/CI on in the monitor menu), night light (hyprsunset), Wi-Fi, Bluetooth.
- Apps to hide on Hyprland only: list IDs in `hypr/hidden-apps.txt`, run `python3 hypr/hide-apps.py` (adds `NotShowIn=Hyprland;`, so KDE still shows them).

Terminal quirk: the ANSI "yellow" slot is sage (`base0A`) and ANSI "magenta" is the real yellow (`base0E`). Shells color commands with **magenta** so they show yellow (zsh `fg=magenta`, pwsh `` `e[35m ``).
