//@ pragma IconTheme breeze
// Quickshell entry point (linked to ~/.config/quickshell, started from hypr/hyprland.lua).
// Run by hand to see errors:  qs   (or: qs -p ~/dotfiles/quickshell)
import QtQuick
import Quickshell

ShellRoot {
    // One wallpaper and one bar per monitor.
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // Opt+? keybind cheat sheet (hidden until toggled)
    Keybinds {}

    // notification server + popups
    Notifications {}

    // control center (click the volume in the bar) and the settings window
    ControlCenter {}
    Settings {}
}
