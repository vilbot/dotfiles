


# --- dotfiles additions (toshy/slices/user_custom_functions.py) ---------------------------
# This slice sits before Toshy's own modmaps, and the first matching multipurpose modmap wins.

# Zed's keymap (dotfiles/zed/build.py) expects the physical Ctrl key to arrive as Super. Make
# held Caps do the same in Zed, so vim's Caps+W h, Caps+D, ... work like on the Mac. (Remapping
# Caps+key combos one by one in a keymap doesn't work: Toshy re-presses the held Left Ctrl
# after each combo, and that stray Ctrl cancels Zed's half-typed "Ctrl+W ..." sequence.)
_hmp_is_zed = matchProps(clas="^dev\\.zed\\.Zed$")
multipurpose_modmap("User: Zed - Caps is Esc / physical Ctrl role", {
    Key.CAPSLOCK:               [Key.ESC, Key.LEFT_META],       # tap Esc / hold Super
}, when = lambda ctx:
    ctx_caps_is_esc_and_lctrl and
    cnfg.screen_has_focus and
    _hmp_is_zed(ctx)
)

