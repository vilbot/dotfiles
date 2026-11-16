// The "None" desktop's shell: the bar, the launcher in it, the top right corner (volume, muted,
// layout, notifications). All text, Hack, gruver16. Started by tty/hyprland.lua; run by hand
// to see errors:  qs -p ~/dotfiles/tty/shell
// State: Launcher, Notes, Status (singletons). What's drawn: Bar, LauncherWindow, Corner.
// The login screen (tty/greeter) runs it with TTY_GREETER=1: only the bar, so logging in looks
// like nothing changes.
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    LazyLoader { active: !Ui.greeter; LauncherWindow {} }
    LazyLoader { active: !Ui.greeter; Corner {} }
    LazyLoader { active: !Ui.greeter; LockScreen {} }   // the login: None waits locked behind it
}
