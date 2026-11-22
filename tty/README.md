# None

An all-terminal desktop on Hyprland. Every window you open from it is a terminal or an app you
chose; the desktop itself is text: a one-line bar with the launcher in it, a Settings app, a
control center, a login screen, a lock and a boot screen that all look like the terminal.

It's a session you add to an Arch install you already have, not a distribution.

## What's in it
- **Launcher** in the bar (Super+Space): apps, favorites, `Files`/`nvim`/`Terminal <path>`,
  websites with `Google Chrome <text>`. An empty desktop is the launcher's prompt.
- **Settings app** ("Settings" in the launcher; Alt+? opens its Shortcuts page): every shortcut, searchable and
  changeable; the colour theme, switched live in every terminal; keyboard and mouse.
- **Control center** (F5): sound, bluetooth, network, updates, and a support bot that reads
  None's own files.
- **Plain Linux keys**: Super runs the desktop, Ctrl stays the apps' key, Super+C/V/X copy,
  paste and cut everywhere.
- **Login screen, lock, boot screen**: optional, in the same look.
- **caret**: shows the keyboard layout at the text cursor when you switch it.

## Needs
Arch or one of its family (CachyOS, EndeavourOS, ...), Hyprland 0.53 or newer (its Lua config),
Quickshell, foot. `install.sh` lists what's missing.

## Install
```sh
git clone <this repo> ~/none && cd ~/none
./install.sh            # no sudo: checks packages, builds caret, makes ~/.config/none
sudo ./session.sh       # a "None" entry in the login screen you have
```
Optional, each with `undo`:
- `sudo ./login.sh`: None's own login screen (greetd) instead of the one you have.
- `sudo ./keys.sh`: Caps Lock taps Esc and holds Ctrl (keyd, system-wide).
- `sudo ./boot.sh`: the boot screen. Needs Plymouth and Limine with limine-mkinitcpio.

`./check.sh` tells you whether everything is in order.

## Yours: `~/.config/none/`
Everything here is optional; `install.sh` puts examples there.

| File | What |
|---|---|
| `machine.lua` | monitors and keyboard layout (Hyprland Lua). The login screen uses it too: run `sudo ./login.sh` again after changing it |
| `user.lua` | anything else for Hyprland, run last: environment, programs to start, window rules |
| `keys.json` | the shortcuts you changed, written by the Settings app |
| `settings.json` | keyboard and mouse options, written by the Settings app |
| `favorites.txt`, `sites.txt` | the launcher's favorites, and websites as `Title https://...` |
| `themes/*.yaml` | your own colour themes (copy one from `themes/`) |
| `help.toml` | which model the support bot uses |

## Editors
None writes its current theme to the file `$NONE_THEME` (JSON: `base00`..`base0F` as `#rrggbb`,
`variant` = `dark` or `light`) and, on a switch, runs `doautocmd User NoneTheme` in every nvim.
A colorscheme that reads the file and an autocmd that loads it again is all nvim needs to follow.

## Known limits
- Websites in the launcher only work with Google Chrome.
- The update tab needs `arch-update` (CachyOS: `cachy-update`).
- The console colours between desktops and the boot screen need Limine.
- Claude Code users: `bin/claude-notify` is a Notification hook that makes its notifications
  work in foot (set it as the hook's command in `~/.claude/settings.json`, through
  `~/.local/share/none/bin/claude-notify`).
