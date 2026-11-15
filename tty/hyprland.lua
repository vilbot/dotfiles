-- "None" desktop: Hyprland dressed as the bare console. Started from the tty login chooser
-- (tty/chooser.sh) with `start-hyprland -- -c ~/dotfiles/tty/hyprland.lua`.
-- Black screen, console font and colours (tty/foot.ini), no bar, wallpaper, gaps, rounding,
-- animations or plugins. Tiling, desktops and mackeys' keys work like on the full desktop:
-- the actions come from hypr/actions.lua, with this desktop's programs.
-- Check: tty/check.sh

local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr/"
local tty = home .. "/dotfiles/tty/"
package.path = hypr .. "?.lua;" .. package.path

-- every terminal here is foot dressed as the console (tty/term)
local term = tty .. "term"
local programs = {
    terminal     = term,
    launcher     = term .. " -a tty-minibuffer " .. tty .. "launch.sh",
    launcher_alt = term .. " -a tty-minibuffer " .. tty .. "launch.sh",
}

-- tty/bin first: apps that ask for a terminal get this desktop's (bin/xdg-terminal-exec)
hl.env("PATH", tty .. "bin:" .. os.getenv("PATH"))

-- the console's colours (Linux VGA palette)
local vga = { black = "000000", gray = "aaaaaa", darkgray = "555555" }
local rgb = function(hex) return "rgba(" .. hex .. "ff)" end

-- how many desktops: `desktops = N` in keys/remap.toml, like the full desktop
local desktops = 5
do
    local f = io.open(home .. "/dotfiles/keys/remap.toml")
    local n = f and f:read("a"):match("\ndesktops%s*=%s*(%d+)")
    if f then f:close() end
    desktops = tonumber(n) or desktops
end

-- Monitors: the modes chosen in the full desktop's settings window (hypr/settings.json); only
-- those, none of its looks. Scale 1 keeps the console font on whole pixels.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "desc:Sony SONY TV", mode = "preferred", position = "auto", scale = 1, mirror = "DP-4" })
for output, m in pairs((require("json").read(hypr .. "settings.json") or {}).monitors or {}) do
    hl.monitor({ output = output, mode = m.mode, position = m.position or "auto", scale = 1 })
end

hl.env("GSK_RENDERER", "ngl") -- same NVIDIA workaround as hypr/hyprland.lua
require("kde")                 -- KDE apps look and work right (hypr/kde.lua)

hl.on("hyprland.start", function()
    -- systemd user services see this session; mackeys takes the keyboard (as in hypr/hyprland.lua)
    hl.exec_cmd("dbus-update-activation-environment --systemd XDG_SESSION_TYPE XDG_SESSION_DESKTOP "
        .. "XDG_CURRENT_DESKTOP WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE "
        .. "QT_QPA_PLATFORMTHEME XDG_MENU_PREFIX GSK_RENDERER "
        .. "&& systemctl --user stop toshy-session-monitor.service toshy-config.service && systemctl --user restart mackeys.service")
    hl.exec_cmd("hypridle")
    -- The session terminal = the console; its shell ending logs out (tty/session.sh).
    hl.exec_cmd(tty .. "session.sh")
end)

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 1,
        col = { active_border = rgb(vga.gray), inactive_border = rgb(vga.darkgray) },
        layout = "dwindle",
    },
    decoration = {
        rounding = 0,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = false },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = rgb(vga.black),
    },
    cursor = { no_warps = true, hide_on_key_press = true, inactive_timeout = 3 },
    render = { cm_auto_hdr = 0 },
    -- same keyboard as hypr/hyprland.lua (mackeys does the Mac keys), except that Ctrl+Alt+F1-F6
    -- (Cmd+Opt+F1-F6) switch consoles, to compare with the real tty
    input = {
        kb_layout = "us,se",
        kb_variant = ",swerty",
        kb_options = "ctrl:nocaps",
        follow_mouse = 2,
        sensitivity = 0,
    },
})

-- A window alone on its desktop has no border, so the session terminal fills the screen exactly
-- like the console (160x45 cells on 2560x1440).
hl.window_rule({ name = "tty-alone-no-border", match = { workspace = "w[tv1]" }, border_size = 0 })

-- The launcher (tty/launch.sh) is a minibuffer: a strip along the bottom of the screen.
hl.window_rule({
    name = "tty-minibuffer",
    match = { class = "^tty-minibuffer$" },
    float = true, pin = true, size = "100% 30%", move = "0 70%",
})

Actions = require("actions")({ programs = programs, desktops = desktops })

-- Mouse: Opt + left-drag moves a window, Opt + right-drag resizes it.
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys of other devices (mackeys doesn't see those).
local media = {
    XF86AudioPlay = "media.playpause", XF86AudioPause = "media.playpause", XF86AudioNext = "media.next",
    XF86AudioPrev = "media.prev", XF86AudioMute = "volume.mute", XF86AudioLowerVolume = "volume.down",
    XF86AudioRaiseVolume = "volume.up",
}
for key, action in pairs(media) do
    hl.bind(key, Actions[action], { locked = true, repeating = action:find("^volume%.[ud]") ~= nil })
end
hl.bind("CTRL + ALT + SUPER + Return", hl.dsp.exec_cmd("systemctl --user restart mackeys.service"))

for i = 1, desktops do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
