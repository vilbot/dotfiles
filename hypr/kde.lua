-- KDE app integration for Hyprland: makes Dolphin, Okular, Ark, ... look and behave like in Plasma.
-- Loaded from hyprland.lua with require("kde").
-- Needs: plasma-integration (comes with Plasma), archlinux-xdg-menu, xdg-desktop-portal-kde.
-- File pickers are chosen in xdg-desktop-portal/hyprland-portals.conf (KDE's open/save dialogs).

-- Qt apps use KDE's platform theme: Breeze style, icons, color scheme and fonts from Plasma's settings.
hl.env("QT_QPA_PLATFORMTHEME", "kde")

-- Dolphin's "Open with" menu is empty outside Plasma without an XDG menu. archlinux-xdg-menu
-- provides arch-applications.menu; KDE's app cache is rebuilt at login so it picks it up.
hl.env("XDG_MENU_PREFIX", "arch-")

hl.on("hyprland.start", function()
    hl.exec_cmd("kbuildsycoca6 --noincremental")
    -- Password prompts for apps that need root (Partition Manager, Discover, ...).
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
end)
