-- What's mine in None (~/.config/none/user.lua): None's hyprland.lua runs it last.
-- None.env / None.path: see the top of None's hyprland.lua.

-- nvim comes from bob
None.path(os.getenv("HOME") .. "/.local/share/bob/nvim-bin")

None.env("GSK_RENDERER", "ngl") -- same NVIDIA workaround as hypr/hyprland.lua
-- SCUF controller dongle: Steam's built-in SDL mapping has buttons and axes wrong (right stick on
-- the triggers' axes, so it reads as held left). This one is measured from its evdev codes and
-- wins over the built-in one; Steam rewrites config.vdf's copy on every start, so it can't live there.
hl.env("SDL_GAMECONTROLLERCONFIG", "03000000952e00004e43000011010000,Gaming SCUF PC Controller Dongle,"
    .. "a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b6,start:b7,guide:b10,"
    .. "leftstick:b8,rightstick:b9,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,"
    .. "leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Linux,")

-- KDE apps (Dolphin, Okular, Ark, ...) look and work as in Plasma, as hypr/kde.lua does for
-- Gallery: Plasma's platform theme, an XDG menu for Dolphin's "Open with", KDE's password prompts
None.env("QT_QPA_PLATFORMTHEME", "kde")
None.env("XDG_MENU_PREFIX", "arch-")

hl.on("hyprland.start", function()
    hl.exec_cmd("kbuildsycoca6 --noincremental")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    -- no key remapper on None: Gallery's mackeys and KDE's Toshy are stopped
    hl.exec_cmd("systemctl --user stop mackeys.service toshy-session-monitor.service toshy-config.service")
end)
