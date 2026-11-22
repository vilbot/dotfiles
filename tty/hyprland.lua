-- "None" desktop: a desktop that is all terminal. Started by tty/start, the login screen's
-- "None" (tty/login.sh).
-- Terminals everywhere (foot, tty/foot.ini: Hack + gruver16), no wallpaper, gaps, rounding
-- or plugins. Plain Linux keys: Super for the desktop, everything else the apps';
-- its keys are tty/keys.json, bound by tty/binds.lua, running tty/actions.lua.
-- What is yours (monitors, keyboard layout, your own environment) is in ~/.config/none.
-- Check: tty/check.sh

local home = os.getenv("HOME")
-- this folder, from this file's own path: None runs from wherever it is
local tty = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
-- yours: ~/.config/none (machine.lua, user.lua, keys.json, settings.json, favorites.txt, ...);
-- all of it optional
local config = (os.getenv("XDG_CONFIG_HOME") or home .. "/.config") .. "/none/"
if not package.path:find(tty .. "?.lua", 1, true) then package.path = tty .. "?.lua;" .. package.path end
local json = require("json")

-- For machine.lua and user.lua:
--   None.dir, None.config   the two folders (with the last /)
--   None.env(NAME, value)   an environment variable that systemd's user services see too
--   None.path(dir)          dir first in PATH, for everything None starts
None = { dir = tty, config = config }
local session_env = { "XDG_SESSION_TYPE", "XDG_SESSION_DESKTOP", "XDG_CURRENT_DESKTOP", "WAYLAND_DISPLAY",
    "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE" }
function None.env(name, value)
    hl.env(name, value)
    session_env[#session_env + 1] = name
end
local path = os.getenv("PATH")
function None.path(dir)
    if not (":" .. path .. ":"):find(":" .. dir .. ":", 1, true) then path = dir .. ":" .. path end
    hl.env("PATH", path)   -- only what's missing: a config reload starts from this PATH again
end
-- a file of yours, when it's there
local function yours(name)
    local f = io.open(config .. name)
    if not f then return end
    f:close()
    dofile(config .. name)
end

-- every terminal here is tty/term (foot with tty/foot.ini)
local term = tty .. "term"
local programs = {
    terminal     = term,
    launcher     = "qs -p " .. tty .. "shell ipc call launcher toggle",  -- in the bar (tty/shell)
    lock         = tty .. "lock",   -- hyprlock: only the password (tty/hyprlock.conf)
    sleep        = "systemctl suspend",   -- tty/hypridle.conf locks first
}

-- tty/bin first: apps that ask for a terminal get this desktop's (bin/xdg-terminal-exec);
-- ~/.local/bin as ~/.zshrc usually adds it, so programs None starts itself (the launcher) find
-- what's there too, not only shells
None.path(home .. "/.local/bin")
None.path(tty .. "bin")
hl.env("NONE_DIR", tty:gsub("/$", ""))   -- tty/hypridle.conf's lock
-- zsh gets logout, shutdown and reboot on top of ~/.zshrc (tty/zsh/.zshrc)
hl.env("ZDOTDIR", tty .. "zsh")

-- colours: None's current theme (tty/theme.py writes it; it sets them live when it changes;
-- editors can read the same file, $NONE_THEME); gruver16 (tty/colors.lua) until one is picked
local theme_file = (os.getenv("XDG_STATE_HOME") or home .. "/.local/state") .. "/none/theme.json"
hl.env("NONE_THEME", theme_file)
local c = require("colors")
do
    local t = json.read(theme_file)
    if t and t.base00 then
        c = {}
        for k, v in pairs(t) do if k:match("^base0") then c[k] = v:gsub("^#", "") end end
    end
end
local rgb = function(hex) return "rgba(" .. hex .. "ff)" end

-- the keys: tty/keys.json, with what you changed laid over it (~/.config/none/keys.json, written
-- by the Settings app); how many desktops: "desktops" in either
local keys = { default = tty .. "keys.json", yours = config .. "keys.json" }
local desktops = tonumber((json.read(keys.yours) or {}).desktops or (json.read(keys.default) or {}).desktops) or 5

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.on("hyprland.start", function()
    -- systemd user services see this session
    hl.exec_cmd("dbus-update-activation-environment --systemd " .. table.concat(session_env, " "))
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
        -- Hyprland's "lock died" screen): from tty2, WAYLAND_DISPLAY=wayland-1 ~/.local/share/none/lock
        allow_session_lock_restore = true,
    },
    cursor = { no_warps = true, hide_on_key_press = true, inactive_timeout = 3 },
    render = { cm_auto_hdr = 0 },
    -- Ctrl+Alt+F1-F6 switch consoles; Caps is Ctrl here too when keyd isn't set up
    input = {
        kb_layout = "us",
        kb_options = "ctrl:nocaps",
        follow_mouse = 2,
        sensitivity = 0,
    },
})

-- your monitors and keyboard (~/.config/none/machine.lua; the login screen uses it too)
yours("machine.lua")

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

-- what the Settings app changed (~/.config/none/settings.json): over everything above
NoneOptions = require("options")
NoneOptions.load(config .. "settings.json")

-- the keys, the mouse and media keys
require("binds")(Actions, keys.default, keys.yours)

for i = 1, desktops do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })

-- everything else of yours (~/.config/none/user.lua), last
yours("user.lua")
