# dotfiles

Personal configs for macOS, Linux (CachyOS) and Windows. **One branch (`main`) for every OS.**
Never create per-OS branches or per-OS copies of a config. Put OS differences inside the file.

## Layout
| Path | App | Linked to (mac + linux / windows) |
|---|---|---|
| `nvim/` | Neovim | `~/.config/nvim` / `%LOCALAPPDATA%\nvim` |
| `wezterm/.wezterm.lua` | WezTerm (mac, windows) | `~/.wezterm.lua` |
| `zed/` | Zed | `~/.config/zed/*` / `%APPDATA%\Zed\*` |
| `herdr/` | Herdr app (terminals + agents; trying it for None): `settings.json` (Herdr writes it too), `themes/<name>.json` (generated). Herdr rewrites the rest of its home (`AGENTS.md`, shipped layouts/mods) on every start | `~/.config/herdr-app/settings.json`, `~/.config/herdr-app/themes/<name>.json` (mac + linux) |
| `ghostty/` | Ghostty (mac, linux) | `~/.config/ghostty` |
| `.zshrc` | zsh (mac, linux) | `~/.zshrc` |
| `powershell/` | pwsh 7 (windows) | `$PROFILE` |
| `jetbrains/` | JetBrains theme plugin | installed manually from `jetbrains/gruver16/gruver16-plugin.zip` |
| `theme/` | color sources (gruver16, gruvnord) + generator | — |
| `keys/` | mackeys (Hyprland): `remap.toml` = the full desktop's keys and desktop shortcuts (None has no remapper), `daemon/` = the Rust remapper | `mackeys.service` → `~/.config/systemd/user/` (linux); it runs `$MACKEYS_KEYMAP`, which hypr/hyprland.lua sets (None stops it) |
| `toshy/` | Toshy (linux, now KDE only) customizations: config slices + tray preferences | written into `~/.config/toshy` by `toshy/apply.py` |
| `hypr/` | Hyprland (linux): `hyprland.lua` + modules (`actions.lua`, `settings.lua` + `json.lua`; `colors.lua` generated), `settings.json` (written by the settings window), `curves.json`, `hidden-apps.txt` | `~/.config/hypr` (linux) |
| `xdg-desktop-portal/` | portal backends for Hyprland (KDE file picker) | `~/.config/xdg-desktop-portal/` (linux) |
| `quickshell/` | Quickshell (linux, Hyprland): the shell; `services/Colors.qml` generated | `~/.config/quickshell` (linux) |
| `none/` | my own config for the "None" desktop, an all-terminal Hyprland. None itself is its own repo, `~/none` (read its `AGENTS.md` before working on it; check: `~/none/check.sh`; `~/none/install.sh` links it to `~/.local/share/none`), and uses nothing from these dotfiles. Here: `machine.lua` (monitors, keyboard; the login screen copies it: `sudo ~/none/login.sh`), `user.lua` (SCUF, NVIDIA, bob, KDE apps), `favorites.txt`, `sites.txt`, `keys.json` (the keys changed) and `settings.json` (both written by None's Settings app) | `~/.config/none` (linux) |
| `kde/env/` | Plasma login scripts | `~/.config/plasma-workspace/env/` (linux) |
| `nvim_old/` | User's own pre-rewrite nvim config, kept for reference. Don't edit or delete. | — |

## prompts/ (gitignored)
The user's messages and task lists for agents. The "None" desktop (`~/none`) and the other Hyprland desktop, called **Gallery** (`hypr/` + `quickshell/`), each have a folder: `prompts/none/`, `prompts/gallery/`. Each has a `todo.md`; its `## Patches` section holds the fixes asked for ("implement the patch" = the open item there), then new features and ideas. Tick an item (`- [x]`) once it's done.

`install.sh` (mac and linux) and `install.ps1` (windows) create all links. When adding a new app config, add it to both scripts if it applies.

## OS-specific code
- **nvim:** use `require("config.platform")` (`is_win`, `is_mac`, `is_linux`), never `has("win32")` directly. See `nvim/README.md`.
- **zsh:** branch on `is_mac` at the top of `.zshrc`. Linux plugins come from `/usr/share/zsh/plugins` (pacman), mac ones from brew.
- **ghostty:** reference themes by name (`theme = gruver16`), never by absolute path. Per-desktop differences go in `ghostty/<desktop>.ghostty`, loaded through the gitignored `session.ghostty` link: Hyprland links it to `hyprland.ghostty` at startup, `kde/env/ghostty-session.sh` removes it at Plasma login.
- **wezterm:** use the `is_win` / `is_mac` locals at the top. Paths go through `dotfiles` (`~/dotfiles`); never hardcode `/Users/...` or `C:\...`.
- **zed:** `settings.json` is shared. `keymap.json` is the Mac keymap and the source of truth. Linux links the generated `keymap.linux.json` (`python3 zed/build.py`, `--check`): Zed's own Linux defaults stay, plus `keymap.json`'s bindings with cmd→ctrl (plain Linux keys, as on None); build.py prints where those replace a Linux default (`zed/upstream/`, refresh on Zed upgrades). On Gallery (mackeys) Zed's keys are off until its rework. Windows still uses the hand-written `keymap.windows.json`.

## Colors: gruver16 family
Each `theme/<name>.yaml` (`gruver16`, `gruvnord`) is the source of truth for that theme. All share gruver16's slot roles. To change a color:
1. Edit `theme/<name>.yaml` (or `theme/templates/zed.json`, shared by all themes, for zed-only details like UI alpha values).
2. Run `python3 theme/build.py`, which regenerates the nvim palette, wezterm, ghostty, zed, herdr and jetbrains themes for every yaml, and from gruver16 alone `hypr/colors.lua` and `quickshell/services/Colors.qml`.
3. `python3 theme/build.py --check` verifies nothing is out of date.

Do not hand-edit generated files (`nvim/lua/palettes/<name>.lua`, `wezterm/colors/<name>.toml`, `ghostty/themes/<name>`, `zed/themes/<name>.json`, `herdr/themes/<name>.json`, `jetbrains/<name>/*`).
None has its own themes and generator (`~/none/themes/`, `theme.py build` there), with its own copy of gruver16: a change to gruver16 is made in both. nvim's colorscheme draws from `palettes/current.lua` (the theme's own palette, or on None the theme in `$NONE_THEME`; `config/autocmds.lua` reloads it on `User NoneTheme`).
`nvim/lua/util/colorscheme.lua` and `jetbrains/build.py` map palette slots to syntax groups by hand; those are fine to edit. `nvim/colors/<name>.lua` are one-line wrappers.

## Keys (mackeys, Hyprland)
- Only the full desktop (Gallery) uses mackeys: `keys/remap.toml`. None has plain Linux keys; `none/user.lua` stops mackeys when None starts. The service runs `$MACKEYS_KEYMAP` (`systemctl --user set-environment`, done by `hypr/hyprland.lua` at start). When keyd runs (None's Caps), mackeys grabs keyd's virtual keyboard (`devices`).
- A layer with `app = "name"` holds that app's own keys: mackeys passes them on unchanged and writes, per action, the keys the app gets (`apps` in keymap.json, by Linux key code), so the app needs no keys of its own.
- `$XDG_RUNTIME_DIR/mackeys.sock`: `record` answers the next keys pressed (`keys opt+shift+1`, `cancelled` after Esc twice) and keeps them from doing anything; `cancel`. The Settings app's Shortcuts page uses it.
- `keys/remap.toml` says what each physical Mac key does: modifier swaps, Caps, per-app layers and desktop actions (with their sheet labels). mackeys reloads it on save and writes the shortcut sheet model to `~/.local/state/mackeys/keymap.json` (Opt+? sheet, Shortcuts page).
- Swerty (the Swedish layout): right Opt is AltGr (`lv3:ralt_switch` in `hypr/hyprland.lua` and `none/machine.lua`); left Opt + ö ä å ´ (±Shift) gives `;:'"[{]}` through the `swerty` layer (`when = { layout = ... }`, output `altgr`), and is plain Alt everywhere else.
- `hypr/actions.lua` is what each action does; mackeys runs `Actions["name"]()` through Hyprland's socket.
- Check: `cargo test` in `keys/daemon` (`tests/remap.rs` runs against the real keymap), then `cargo build --release`; `journalctl --user -u mackeys` shows reloads, missing actions and errors.
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
