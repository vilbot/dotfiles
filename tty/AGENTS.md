# None

An all-terminal desktop on Hyprland (see `README.md`). This folder is the whole project: nothing
in it may use files outside it, except the user's own in `~/.config/none/` (all optional) and
state in `~/.local/state/none/`. `check.sh` verifies that; it must pass after every change.
Paths below are relative to this folder (until it has its own repo, that is `tty/`).

## Layout
| Path | What |
|---|---|
| `hyprland.lua` | the Hyprland config (Lua, Hyprland 0.53+; stubs: `/usr/share/hypr/stubs/hl.meta.lua`), started by `start`. Finds this folder from its own path, sets `$NONE_DIR`, `$NONE_THEME`. Loads `~/.config/none/machine.lua` (monitors, keyboard) and, last, `user.lua`; the global `None` (`dir`, `config`, `env()`, `path()`) is for those |
| `keys.json`, `binds.lua`, `actions.lua` | the desktop keys (plain Linux keys, no remapper: Super for the desktop, Ctrl in apps; universal clipboard Super+C/V/X sends Ctrl+Insert / Shift+Insert / Ctrl+X, which `foot.ini` copies/pastes on; AltGr + F-key = the plain F-key), bound by `binds.lua` to the actions in `actions.lua`. Under `apps`: the launcher's and the Settings app's own keys (`shell/AppKeys.qml`, matched by Linux key code). The user's changes are `~/.config/none/keys.json` (`{ "keys": { action: [keys] }, "desktops": n }`), laid over `keys.json` by every reader |
| `term`, `foot.ini` | every terminal: foot with this config. `zsh/.zshrc` adds `logout`/`lock`/`shutdown`/`reboot` on top of the user's `~/.zshrc` |
| `shell/` | the Quickshell, all text: the bar (focused app + title; icons per control center tab) with the launcher in it (`~/.config/none/favorites.txt`; `Files`/`nvim`/`Terminal <path>`; `Google Chrome <text>`: `sites.txt`, Chrome's history, Google's suggestions), an empty desktop shows the launcher as a prompt (`EmptyDesk.qml`), notifications, volume/brightness/layout |
| `settings/`, `settings.sh [PAGE]` | the Settings app (its own Quickshell window, class `none-settings`): Shortcuts (recording switches Hyprland to the empty submap `none-record`; saving writes the user's `keys.json` and runs `hyprctl reload`), Appearance (the colour theme), Keyboard & mouse (`~/.config/none/settings.json`, applied by `options.lua`) |
| `panel.sh`, `panel/` | the control center (F5, or `panel.sh TAB`): tabs and keys in `panel/panel.py`; the update tab runs arch-update / cachy-update in `panel/update.py`, which outlives the panel; `panel/help.py` is the support bot (`help.toml`) |
| `theme.py`, `themes/` | colour themes: 16 slots + `variant`, here and in `~/.config/none/themes/`. `theme.py set NAME` switches live: shell, open terminals, Hyprland, the lock, GTK/Qt light/dark (`appearance.sh`), and nvim through `User NoneTheme`. `theme.py build` regenerates the gruver16 defaults (`colors.lua`, `foot-colors.ini`, `shell/Colors.qml`): do not hand-edit those |
| `caret/` | Rust (`cargo build --release`): an input method that types nothing, only shows the new keyboard layout at the text cursor (apps with text-input-v3: foot, GTK; else the corner shows it) |
| `lock`, `hyprlock.conf`, `hypridle.conf` | the lock (hyprlock; before sleep, Super+Ctrl+Q) |
| `install.sh` | user-level setup, no sudo: packages check, caret, the `~/.local/share/none` link, `~/.config/none` from `defaults/` |
| `session.sh`, `login.sh`, `keys.sh`, `boot.sh` | opt-in, sudo, each with `undo`: a session entry; greetd with the login screen `greeter/` (a copy in `/etc/greetd/none`, with the user's `machine.lua`); keyd for Caps (`keyd.conf`); the boot screen (`boot/plymouth.py`, `boot/limine.py`; Limine only) |
| `bin/` | first on PATH inside None: `xdg-terminal-exec`, `screenshot`, `claude-notify` |

## Rules
- Arch and its family only. A sudo script checks for what it needs and says what it skipped.
- Nothing personal in this folder (monitors, layouts, favorites, machine workarounds): that is `~/.config/none/`.
- The ANSI "yellow" slot is sage (`base0A`) and ANSI "magenta" is the real yellow (`base0E`).
- Quickshell hot-reloads `shell/` when a file changes; `qs -p shell log` shows QML errors.
- After editing: `./check.sh`. It runs `Hyprland --verify-config`, checks keys, themes, scripts,
  that this folder names nothing outside itself, and that a copy of it works with an empty home.
