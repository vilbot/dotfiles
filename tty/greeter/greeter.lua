-- The login screen's Hyprland (run by greetd as the "greeter" user, from /etc/greetd/none, where
-- tty/login.sh copies this folder and what it needs). It looks like None right after logging
-- in: the bar, one terminal; the terminal asks who you are (greeter.py).
local here = "/etc/greetd/none/"
package.path = here .. "?.lua;" .. package.path
local c = require("colors")
local rgb = function(hex) return "rgba(" .. hex .. "ff)" end

-- same monitors as None (copied from hypr/settings.json)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({ output = "desc:Sony SONY TV", mode = "preferred", position = "auto", scale = 1, mirror = "DP-4" })
for output, m in pairs((require("json").read(here .. "settings.json") or {}).monitors or {}) do
    hl.monitor({ output = output, mode = m.mode, position = m.position or "auto", scale = m.scale or "auto" })
end

hl.config({
    general = { gaps_in = 0, gaps_out = 0, border_size = 0, layout = "dwindle" },
    decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } },
    animations = { enabled = false },
    misc = {
        disable_hyprland_logo = true, disable_splash_rendering = true,
        background_color = rgb(c.base00),
    },
    input = { kb_layout = "us,se", kb_variant = ",swerty", kb_options = "ctrl:nocaps" },
    cursor = { inactive_timeout = 1 },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("env TTY_GREETER=1 qs -p " .. here .. "shell")
    hl.exec_cmd("foot -c " .. here .. "foot.ini -a tty-session python3 " .. here .. "greeter.py")
end)
