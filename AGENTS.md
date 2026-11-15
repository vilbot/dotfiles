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
| `keys/daemon/` + `keys/remap.toml` | mackeys, the Mac keyboard on Hyprland (replaces Toshy there); `cargo test` in `keys/daemon` | `mackeys.service` → `~/.config/systemd/user/` (linux) |
| `toshy/` | Toshy (linux, now KDE only) customizations: config slices + tray preferences | written into `~/.config/toshy` by `toshy/apply.py` |
| `hypr/` | Hyprland (linux): `hyprland.lua` + modules (`binds.lua`, `colors.lua` generated; `settings.lua` written by the settings app), `hidden-apps.txt` | `~/.config/hypr` (linux) |
| `xdg-desktop-portal/` | portal backends for Hyprland (KDE file picker) | `~/.config/xdg-desktop-portal/` (linux) |
| `quickshell/` | Quickshell (linux, Hyprland): bar, wallpaper, notifications, control center, settings window, command palette, Cmd+Tab app switcher, Opt+? keybind sheet; `Colors.qml` generated | `~/.config/quickshell` (linux) |
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

Do not hand-edit `keys/generated/*` (including `keymap.json`, the model for the Opt+? sheet and the Shortcuts page) or `hypr/binds.lua`. `keymap.toml` lists every action in `HYPR_ACTIONS` (unbound ones as `[]`); a new action needs an entry in `HYPR_ACTIONS` (plus `KDE_ACTIONS` if KDE has an equivalent), a line in `keymap.toml` and a label in `SHEET` (sections for the Opt+? sheet and the settings window; the build fails without them).
A key can differ per desktop: `{ hypr = "...", kde = "..." }`; without `kde`, KDE uses the Hyprland key.
The settings window's Shortcuts page (`quickshell/ShortcutsPage.qml`, model `quickshell/Keymap.qml`, which reads `keys/generated/keymap.json`: files the shell reads inside `quickshell/` make Quickshell restart when they change, so generated/state files live elsewhere) edits keymap.toml through `keys/build.py --set <json> --apply`, which keeps comments and puts the file back if the build fails.

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
- Cmd+Tab app switcher (`quickshell/AppSwitcher.qml`): Toshy sends Cmd+Tab as Alt+Tab with Alt held, `binds.lua` sends it to Quickshell global shortcuts (`quickshell:switcher-next/prev`), and letting go of Cmd is noticed by `quickshell/scripts/wait-alt-release.py` (polls the keyboards' key state; Hyprland's Alt release binds in `hyprland.lua` are only a fallback).
- Idle: `hypr/hypridle.conf` (hyprlang, not Lua; hypridle is started from `hyprland.lua`) only turns the screen off after 2 hours. No lock screen, no sleep.
- `settings.lua` is written by the Quickshell settings window (`quickshell/Settings.qml`: Hyprland options + monitor modes) and applied last in `hyprland.lua`. Changing an option there overrides the value in `hyprland.lua`; per-monitor modes live only there. Keep its one-entry-per-line format (the app parses it back).
- Control center (`quickshell/ControlCenter.qml`, the switches icon in the bar): sound, brightness, night light, Wi-Fi, Bluetooth. Brightness (also F1/F2, `qs ipc call brightness up|down`) goes over DDC/CI (ddcutil) when the monitor answers; the Samsung doesn't on NVIDIA's open driver, so it falls back to dimming with hyprsunset's gamma. One `hyprsunset --identity` runs with the shell and does both dimming and night light (`hyprctl hyprsunset gamma|temperature|identity`).
- Wallpaper (`quickshell/Wallpaper.qml`, `WallpaperState.qml`, settings page `WallpaperPage.qml`): one path, a picture or a folder (slideshow in name order, interval + transition fade/slide/zoom/none). Saved in `~/.local/state/quickshell/wallpaper.json`; `qs ipc call wallpaper set <path>`.
- Mission control: hymission, F3 = this desktop without search (hidden pick labels on; not vim_keys, which warns every time it's turned on), F4 = all windows with its search box (`overview.*` in `keymap.toml`, the binds in `keys/build.py`), desktop strip at the top (PLUGINS in `hyprland.lua`). While its search box is up, hymission routes keys to it and doesn't move real focus, so F3 has none. `hypr/overview-flag.sh` keeps `$XDG_RUNTIME_DIR/hymission-open` (+ `hymission-search`) while it's open: Toshy turns h/j/k/l and Opt+h/j/k/l into arrows then (only Opt+h/j/k/l, to Up/Down, while its search box is up; hyprland.lua removes leftover flags at start), and Opt+Tab focuses the new desktop's leftmost window. Desktops 1-5 are persistent workspaces (the overview fails switching to one that doesn't exist yet). The search box is styled by `hypr/hymission-search.css` via `~/.config/gtk-4.0/gtk.css`.
- Screenshots: the keyboard's screenshot key (= Cmd+Shift+4, `screenshot.region` in `keys/keymap.toml`) opens HyprCapture when that plugin is loaded, else `hypr/screenshot.sh` (drag an area, saved to `~/Pictures/Screenshots`, copied with wl-copy, shown as a notification).
- F-row works like a Mac keyboard's: Toshy turns F1–F12 into the functions printed on the keys (`toshy/slices/user_custom_modmaps.py`; F5/F6 send F17/F18 because Toshy keeps F15/F16 for itself), right Option + F-key gives the plain F-key (`user_apps.py`). In `keymap.toml`, `f1`..`f12` mean those keys; `keys/build.py` `FKEY_SENT` says what Hyprland receives. The NuPhy itself sends plain F-keys with or without its Fn key.
- Dark / light mode (F6): `hypr/appearance.sh toggle|dark|light|get` sets gsettings `color-scheme` (GTK 4, the portal, so Chrome and websites), `gtk-theme` (GTK 3) and the KDE color scheme (Qt apps). Quickshell's `Theme.qml` follows `color-scheme` by itself; use Theme colors (and `SymbolIcon` for one-color icons) so components switch too. Ghostty, Zed and nvim stay gruver16 (dark).
- `GSK_RENDERER=ngl` (in `hyprland.lua`): workaround for Ghostty's active tab flickering black, likely GTK's default Vulkan renderer on the NVIDIA card. Remove it if it doesn't help.
- Plugins (hymission, HyprCapture, hyprglass) come from `hyprpm` (installed by the user, built against the running Hyprland) and are loaded at start with `hyprpm reload -n`. After a Hyprland upgrade: `hyprpm update`. Their Lua tables (`hl.plugin.<name>`) only exist once loaded, so guard config and binds that use them (the PLUGINS section of `hyprland.lua`). hyprglass puts liquid glass under the Quickshell layers and unfocused windows; Quickshell's backgrounds (`Theme.wall/panel/card`) stay see-through for it, and `appearance.sh` switches its light/dark theme. Its look is set on the settings window's Glass page (a style, or your own sliders, which only apply to the "default" style; built-in styles set those values themselves). Screenshots never show the glass (the plugin skips captures), so check it on screen.
- Apps to hide on Hyprland only: list IDs in `hypr/hidden-apps.txt`, run `python3 hypr/hide-apps.py` (adds `NotShowIn=Hyprland;`, so KDE still shows them).

Terminal quirk: the ANSI "yellow" slot is sage (`base0A`) and ANSI "magenta" is the real yellow (`base0E`). Shells color commands with **magenta** so they show yellow (zsh `fg=magenta`, pwsh `` `e[35m ``).
