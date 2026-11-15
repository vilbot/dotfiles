//@ pragma IconTheme breeze
//@ pragma UseQApplication
// The shell (Hyprland): bar and wallpaper on every monitor, and the panels, which stay hidden
// until opened. services/ holds the state they share, widgets/ the controls they're built from.
// Run by hand to see errors:  qs -p ~/dotfiles/quickshell
import QtQuick
import Quickshell
import qs.bar
import qs.wallpaper
import qs.notifications
import qs.controlcenter
import qs.settings
import qs.palette
import qs.switcher
import qs.keybinds

ShellRoot {
    Variants {
        model: Quickshell.screens
        WallpaperLayer {}
    }
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Popups {}
    History {}
    ControlCenter {}
    SettingsWindow {}
    CommandPalette {}
    AppSwitcher {}
    KeySheet {}
}
