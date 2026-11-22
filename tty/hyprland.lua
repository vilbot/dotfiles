-- "None" desktop: a desktop that is all terminal. Started by tty/start, the login screen's
-- "None" (tty/login.sh).
-- Terminals everywhere (foot, tty/foot.ini: Hack + gruver16), no wallpaper, gaps, rounding
-- or plugins. Its own keys (tty/keys.toml, through mackeys) and actions (tty/actions.lua).
-- Check: tty/check.sh

local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr/"
local tty = home .. "/dotfiles/tty/"
package.path = tty .. "?.lua;" .. hypr .. "?.lua;" .. package.path   -- tty/ first: its own actions.lua

-- every terminal here is tty/term (foot with tty/foot.ini)
local term = tty .. "term"
local programs = {
    terminal     = term,
    launcher     = "qs -p " .. tty .. "shell ipc call launcher toggle",  -- in the bar (tty/shell)
    lock         = tty .. "lock",   -- hyprlock: only the password (tty/hyprlock.conf)
    sleep        = "systemctl suspend",   -- tty/hypridle.conf locks first
}

-- tty/bin first: apps that ask for a terminal get this desktop's (bin/xdg-terminal-exec)
-- plus what ~/.zshrc adds (~/.local/bin; nvim from bob), so programs None starts itself (the
-- launcher) find them too, not only shells
do
    local path = os.getenv("PATH")
    for _, dir in ipairs({ home .. "/.local/share/bob/nvim-bin", home .. "/.local/bin", tty .. "bin" }) do
        if not (":" .. path .. ":"):find(":" .. dir .. ":", 1, true) then path = dir .. ":" .. path end
    end
    hl.env("PATH", path)   -- only what's missing: a config reload starts from this PATH again
end
-- zsh gets logout, shutdown and reboot on top of ~/.zshrc (tty/zsh/.zshrc)
hl.env("ZDOTDIR", tty .. "zsh")

-- colours: None's current theme (tty/theme.py writes it; it sets them live when it changes, and
-- nvim reads the same file, $NONE_THEME); gruver16 (hypr/colors.lua) until one is picked
local theme_file = home .. "/.local/state/none/theme.json"
hl.env("NONE_THEME", theme_file)
local c = require("colors")
do
    local t = require("json").read(theme_file)
    if t and t.base00 then
        c = {}
        for k, v in pairs(t) do if k:match("^base0") then c[k] = v:gsub("^#", "") end end
    end
end
local rgb = function(hex) return "rgba(" .. hex .. "ff)" end

-- how many desktops: `desktops = N` in tty/keys.toml
local desktops = 5
do
    local f = io.open(tty .. "keys.toml")
    local n = f and f:read("a"):match("\ndesktops%s*=%s*(%d+)")
    if f then f:close() end
    desktops = tonumber(n) or desktops
end

-- Monitors: the modes chosen in the full desktop's settings window (hypr/settings.json); only
-- those, none of its looks.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({ output = "desc:Sony SONY TV", mode = "preferred", position = "auto", scale = 1, mirror = "desc:Samsung Electric Company LS27FG53x" })  -- by description: connector names change (DP-4 became DP-1 with NVIDIA loading early)
for output, m in pairs((require("json").read(hypr .. "settings.json") or {}).monitors or {}) do
    hl.monitor({ output = output, mode = m.mode, position = m.position or "auto", scale = m.scale or "auto" })
end

hl.env("GSK_RENDERER", "ngl") -- same NVIDIA workaround as hypr/hyprland.lua
-- SCUF controller dongle: Steam's built-in SDL mapping has buttons and axes wrong (right stick on
-- the triggers' axes, so it reads as held left). This one is measured from its evdev codes and
-- wins over the built-in one; Steam rewrites config.vdf's copy on every start, so it can't live there.
hl.env("SDL_GAMECONTROLLERCONFIG", "03000000952e00004e43000011010000,Gaming SCUF PC Controller Dongle,"
    .. "a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b6,start:b7,guide:b10,"
    .. "leftstick:b8,rightstick:b9,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,"
    .. "leftx:a0,lefty:a1,rightx:a2,righty:a5,lefttrigger:a3,righttrigger:a4,platform:Linux,")
require("kde")                 -- KDE apps look and work right (hypr/kde.lua)

hl.on("hyprland.start", function()
    -- systemd user services see this session; mackeys takes the keyboard, with None's keys
    hl.exec_cmd("dbus-update-activation-environment --systemd XDG_SESSION_TYPE XDG_SESSION_DESKTOP "
        .. "XDG_CURRENT_DESKTOP WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE "
        .. "QT_QPA_PLATFORMTHEME XDG_MENU_PREFIX GSK_RENDERER "
        .. "&& systemctl --user set-environment MACKEYS_KEYMAP=" .. tty .. "keys.toml "
        .. "&& systemctl --user stop toshy-session-monitor.service toshy-config.service && systemctl --user restart mackeys.service")
    hl.exec_cmd("hypridle -c " .. tty .. "hypridle.conf")
    -- the bar with the launcher, volume, keyboard layout and notifications (tty/shell)
    hl.exec_cmd("qs -p " .. tty .. "shell")
    -- the keyboard layout at the text cursor when it changes (an input method that types nothing;
    -- built with `cargo build --release` in tty/caret)
    hl.exec_cmd(tty .. "caret/target/release/none-caret")
    -- no terminal: an empty desktop is the launcher's prompt (tty/shell/EmptyDesk.qml)
end)

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 1,
        col = { active_border = rgb(c.base0D), inactive_border = rgb(c.base02) },
        layout = "dwindle",
    },
    decoration = {
        rounding = 0,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = rgb(c.base00),
        focus_on_activate = true,   -- clicking a notification brings its window forward
        -- a lock (hyprlock, tty/lock) started again after a crash takes over (instead of
        -- Hyprland's "lock died" screen): from tty2, WAYLAND_DISPLAY=wayland-1 ~/dotfiles/tty/lock
        allow_session_lock_restore = true,
    },
    cursor = { no_warps = true, hide_on_key_press = true, inactive_timeout = 3 },
    render = { cm_auto_hdr = 0 },
    -- same keyboard as hypr/hyprland.lua (mackeys does the Mac keys), except that Ctrl+Alt+F1-F6
    -- (Cmd+Opt+F1-F6) switch consoles
    input = {
        kb_layout = "us,se",
        kb_variant = ",swerty",
        kb_options = "ctrl:nocaps,lv3:ralt_switch",   -- right Opt = AltGr: swerty's ;:'"[]{} (the US layout's Alt_R otherwise wins)
        follow_mouse = 2,
        sensitivity = 0,
    },
})

-- A window alone on its desktop has no border: one terminal = the whole screen.
hl.window_rule({ name = "tty-alone-no-border", match = { workspace = "w[tv1]" }, border_size = 0 })


-- The settings panel (tty/panel.sh): down the right side, over the windows.
hl.window_rule({
    name = "tty-panel",
    match = { class = "^tty-panel$" },
    float = true, pin = true, border_size = 1, animation = "slide right",
    size = "(monitor_w*0.3) (monitor_h-28)", move = "(monitor_w*0.7) 28",  -- under the bar (tty/shell/Ui.qml)
})

-- Motion: the shell's (tty/shell, Ui.quick): 140ms, easing out, a fade with a small move.
-- Its own surfaces animate themselves, so Hyprland leaves layers alone.
hl.curve("quick", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 1.4, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 1.4, bezier = "quick", style = "popin 97%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.4, bezier = "quick", style = "fade" })

Actions = require("actions")({ tty = tty, programs = programs, desktops = desktops })

-- what the Settings app changed (tty/settings.json): over everything above
NoneOptions = require("options")
NoneOptions.load(tty .. "settings.json")

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
