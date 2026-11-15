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
| `keys/` | mackeys (Hyprland): `remap.toml` = every key and desktop shortcut, `daemon/` = the Rust remapper | `mackeys.service` → `~/.config/systemd/user/` (linux) |
| `toshy/` | Toshy (linux, now KDE only) customizations: config slices + tray preferences | written into `~/.config/toshy` by `toshy/apply.py` |
| `hypr/` | Hyprland (linux): `hyprland.lua` + modules (`actions.lua`, `settings.lua` + `json.lua`; `colors.lua` generated), `settings.json` (written by the settings window), `curves.json`, `hidden-apps.txt` | `~/.config/hypr` (linux) |
| `xdg-desktop-portal/` | portal backends for Hyprland (KDE file picker) | `~/.config/xdg-desktop-portal/` (linux) |
| `quickshell/` | Quickshell (linux, Hyprland): the shell; `services/Colors.qml` generated | `~/.config/quickshell` (linux) |
| `tty/` | "None" desktop: an all-terminal Hyprland (`hyprland.lua`, started by `start`; every terminal is `term` = foot with `foot.ini`; launcher `launch.sh` + `favorites.txt`; zsh there adds `logout`/`shutdown`/`reboot` via `zsh/.zshrc`) and the login screen for all desktops (`login.sh`: greetd + tuigreet, run with sudo). Check: `tty/check.sh` | — |
| `kde/env/` | Plasma login scripts | `~/.config/plasma-workspace/env/` (linux) |
| `nvim_old/` | User's own pre-rewrite nvim config, kept for reference. Don't edit or delete. | — |

`install.sh` (mac and linux) and `install.ps1` (windows) create all links. When adding a new app config, add it to both scripts if it applies.

## OS-specific code
- **nvim:** use `require("config.platform")` (`is_win`, `is_mac`, `is_linux`), never `has("win32")` directly. See `nvim/README.md`.
- **zsh:** branch on `is_mac` at the top of `.zshrc`. Linux plugins come from `/usr/share/zsh/plugins` (pacman), mac ones from brew.
- **ghostty:** reference themes by name (`theme = gruver16`), never by absolute path. Per-desktop differences go in `ghostty/<desktop>.ghostty`, loaded through the gitignored `session.ghostty` link: Hyprland links it to `hyprland.ghostty` at startup, `kde/env/ghostty-session.sh` removes it at Plasma login.
- **wezterm:** use the `is_win` / `is_mac` locals at the top. Paths go through `dotfiles` (`~/dotfiles`); never hardcode `/Users/...` or `C:\...`.
- **zed:** `settings.json` is shared. `keymap.json` is the Mac keymap and the source of truth. Linux links the generated `keymap.linux.json` (`python3 zed/build.py`, `--check`): it unbinds Zed's Linux defaults and rebinds the Mac defaults (`zed/upstream/`, refresh on Zed upgrades) + `keymap.json`, translated for mackeys (cmd→ctrl, ctrl→super); the `zed` layer in `keys/remap.toml` passes Zed's keys through. Windows still uses the hand-written `keymap.windows.json`.

## Colors: gruver16
`theme/gruver16.yaml` is the single source of truth. To change a color:
1. Edit `theme/gruver16.yaml` (or `theme/templates/zed.json` for zed-only details like UI alpha values).
2. Run `python3 theme/build.py`, which regenerates the nvim palette, wezterm, ghostty, foot (tty), zed and jetbrains themes.
3. `python3 theme/build.py --check` verifies nothing is out of date.

Do not hand-edit generated files (`nvim/lua/palettes/gruver16.lua`, `wezterm/colors/gruver16.toml`, `ghostty/themes/gruver16`, `tty/foot-colors.ini`, `zed/themes/gruver16.json`, `jetbrains/gruver16/*`).
`nvim/colors/custom.lua` and `jetbrains/build.py` map palette slots to syntax groups by hand; those are fine to edit.

## Keys (mackeys, Hyprland)
- `keys/remap.toml` says what each physical Mac key does: modifier swaps, Caps, per-app layers and desktop actions (with their sheet labels). mackeys reloads it on save and writes the shortcut sheet model to `~/.local/state/mackeys/keymap.json` (Opt+? sheet, Shortcuts page).
- `hypr/actions.lua` is what each action does; mackeys runs `Actions["name"]()` through Hyprland's socket.
- Check: `cargo test` in `keys/daemon` (runs against the real `remap.toml`), then `cargo build --release`; `journalctl --user -u mackeys` shows reloads, missing actions and errors.
- KDE still uses Toshy (`toshy/`, written in by `python3 toshy/apply.py`; its installer regenerates `toshy_config.py`, keeping only the slices).

## Hyprland (linux)
- Config is **Lua** (`hypr/hyprland.lua`, Hyprland 0.53+), not hyprlang `.conf`. API stubs: `/usr/share/hypr/stubs/hl.meta.lua`.
- Modules are loaded with `require`: `actions.lua` (desktop actions), `settings.lua` (applies `settings.json` and `curves.json`), `colors.lua` (generated by `theme/build.py`), `kde.lua` (KDE app integration).
- Always run `Hyprland --verify-config -c hypr/hyprland.lua` after editing; it checks dispatcher arguments too.
- The Sony TV mirrors the Samsung (monitor rule in `hyprland.lua`).
- Idle: `hypr/hypridle.conf` (hyprlang, not Lua; hypridle is started from `hyprland.lua`) only turns the screen off after 2 hours. No lock screen, no sleep.
- `settings.json` holds what the settings window changed (Hyprland options, animations, monitor modes); `settings.lua` applies it last, so it wins over `hyprland.lua`. Per-monitor modes live only there.
- Mission control: hymission, F3 = this desktop without search (hidden pick labels on; not vim_keys, which warns every time it's turned on), F4 = all windows with its search box (`overview.*` in `keys/remap.toml` and `hypr/actions.lua`), desktop strip at the top (PLUGINS in `hyprland.lua`). While its search box is up, hymission routes keys to it and doesn't move real focus, so F3 has none. While it's open, mackeys turns h/j/k/l and Opt+h/j/k/l into arrows (only Opt+h/j/k/l, to Up/Down, while its search box is up), and Opt+Tab focuses the new desktop's leftmost window. Desktops 1-5 are persistent workspaces (the overview fails switching to one that doesn't exist yet). The search box is styled by `hypr/hymission-search.css` via `~/.config/gtk-4.0/gtk.css`.
- Screenshots: the keyboard's screenshot key (= Cmd+Shift+4, `screenshot.region` in `keys/remap.toml`) opens HyprCapture when that plugin is loaded, else `hypr/screenshot.sh` (drag an area, saved to `~/Pictures/Screenshots`, copied with wl-copy, shown as a notification).
- F-row works like a Mac keyboard's: F1–F12 run the functions printed on the keys, right Option + F-key gives the plain F-key (`keys/remap.toml`). The NuPhy itself sends plain F-keys with or without its Fn key.
- Dark / light mode (F6): `hypr/appearance.sh toggle|dark|light|get` sets gsettings `color-scheme` (GTK 4, the portal, so Chrome and websites), `gtk-theme` (GTK 3) and the KDE color scheme (Qt apps). Quickshell follows `color-scheme` by itself. Ghostty, Zed and nvim stay gruver16 (dark).
- `GSK_RENDERER=ngl` (in `hyprland.lua`): workaround for Ghostty's active tab flickering black, likely GTK's default Vulkan renderer on the NVIDIA card. Remove it if it doesn't help.
- Plugins (hymission, HyprCapture, hyprglass) come from `hyprpm` (installed by the user, built against the running Hyprland) and are loaded at start with `hyprpm reload -n`. After a Hyprland upgrade: `hyprpm update`. Their Lua tables (`hl.plugin.<name>`) only exist once loaded, so guard config and binds that use them (the PLUGINS section of `hyprland.lua`). hyprglass puts liquid glass under the Quickshell layers and unfocused windows; Quickshell's backgrounds (`Theme.wall/panel/card`) stay see-through for it, and `appearance.sh` switches its light/dark theme. Its look is set on the settings window's Glass page (a style, or your own sliders, which only apply to the "default" style; built-in styles set those values themselves). Screenshots never show the glass (the plugin skips captures), so check it on screen.
- Apps to hide on Hyprland only: list IDs in `hypr/hidden-apps.txt`, run `python3 hypr/hide-apps.py` (adds `NotShowIn=Hyprland;`, so KDE still shows them).

## Shell (Quickshell, Hyprland)
- `quickshell/shell.qml` lists the parts. `services/` = shared state (singletons, `import qs.services`), `widgets/` = shared controls (`import qs.widgets`), one folder per feature (`bar/`, `controlcenter/`, `notifications/`, `settings/`, `palette/`, `switcher/`, `keybinds/`, `wallpaper/`).
- Settings window pages: `quickshell/settings/schema.js`.
- Check: `qs kill; hyprctl eval 'hl.exec_cmd("qs")'`, then `qs log` shows QML errors; `qs ipc call <target> <function>` opens panels and pages.

Terminal quirk: the ANSI "yellow" slot is sage (`base0A`) and ANSI "magenta" is the real yellow (`base0E`). Shells color commands with **magenta** so they show yellow (zsh `fg=magenta`, pwsh `` `e[35m ``).
