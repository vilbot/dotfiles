-- Settings changed in the Quickshell settings app (quickshell/Settings.qml). hyprland.lua applies
-- them last, over its own values. The app rewrites this file: keep one entry per line.
return {
    options = {
        ["decoration:active_opacity"] = 1,
        ["decoration:blur:ignore_opacity"] = true,
        ["decoration:blur:noise"] = 0,
        ["decoration:blur:popups"] = false,
        ["decoration:blur:size"] = 2,
        ["decoration:blur:variant"] = 0,
        ["decoration:dim_inactive"] = true,
        ["decoration:dim_strength"] = 0.4,
        ["decoration:fullscreen_opacity"] = 1,
        ["decoration:shadow:enabled"] = true,
        ["general:border_size"] = 0,
        ["input:follow_mouse"] = 1,
        ["input:sensitivity"] = -0.5,
    },
    animations = {
        ["borderangle"] = { enabled = false, speed = 1, curve = "default", style = "" },
        ["workspaces"] = { enabled = true, speed = 5, curve = "quick", style = "" },
    },
    monitors = {
        ["desc:Samsung Electric Company LS27FG53x"] = { mode = "2560x1440@200.00", scale = 1 },
    },
}
