
# --- dotfiles additions (toshy/slices/user_custom_modmaps.py) ------------------------------

# Mac-style F-row. The NuPhy sends plain F1–F12 whether or not its Fn key is held, so Toshy does
# what a Mac keyboard does: F1–F12 send the function printed on the key, and right Option + an
# F-key gives the plain F-key (keymap "User: right Option + F-key" in the user_apps slice).
# The desktops bind what these send (dotfiles/keys/keymap.toml; keys/build.py: FKEY_SENT).
# F5 and F6 send F17 / F18, keys no keyboard has (Toshy keeps F15 / F16 for itself).
modmap("User: Mac F-row", {
    Key.F1:                     Key.BRIGHTNESSDOWN,
    Key.F2:                     Key.BRIGHTNESSUP,
    Key.F3:                     Key.SCALE,          # Mission Control
    Key.F4:                     Key.SEARCH,
    Key.F5:                     Key.F17,            # microphone key -> settings
    Key.F6:                     Key.F18,            # moon key -> dark / light mode
    Key.F7:                     Key.REWIND,
    Key.F8:                     Key.PLAYPAUSE,
    Key.F9:                     Key.FASTFORWARD,
    Key.F10:                    Key.MUTE,
    Key.F11:                    Key.VOLUMEDOWN,
    Key.F12:                    Key.VOLUMEUP,
}, when = lambda ctx:
    cnfg.screen_has_focus and
    not ctx_app_is_remote
)

