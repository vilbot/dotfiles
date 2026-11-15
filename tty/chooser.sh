# The desktop chooser after a tty login (sourced by ~/.zprofile on a real console).
#   n / Enter  None: Hyprland dressed as this console (tty/hyprland.lua)
#   h          Hyprland (the full desktop, hypr/hyprland.lua)
#   k          KDE Plasma
#   s / Ctrl+D a plain shell here (for fixing a broken desktop)
# Leaving a desktop ends this login, so you're back at the login prompt.

# A session's command line, as the login manager would run it.
_tty_session_exec() {
    sed -n 's/^Exec=//p' "/usr/share/wayland-sessions/$1.desktop" | head -n1
}

_tty_choose() {
    local key
    print -n "desktop [None/hyprland/kde/shell]: "
    read -k1 key || { print; return }  # Ctrl+D
    [[ $key == $'\n' ]] || print
    case ${key:l} in
        $'\n'|n) exec start-hyprland -- -c ~/dotfiles/tty/hyprland.lua ;;
        h) exec ${=$(_tty_session_exec hyprland)} ;;
        k) exec ${=$(_tty_session_exec plasma)} ;;
        s|$'\x04') ;;
        *) _tty_choose ;;
    esac
}

_tty_choose
unfunction _tty_choose _tty_session_exec
