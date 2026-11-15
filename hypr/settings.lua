-- What the Quickshell settings window changed (settings.json, written only by it), applied over
-- hyprland.lua's own values. The window also sends each change straight here while you drag:
-- `hyprctl eval 'Settings.apply_json([==[{"options": {"general:gaps_in": 6}}]==])'`.
--
-- settings.json: {
--   "options":    { "general:gaps_in": 6, ... },
--   "animations": { "windowsIn": { "enabled": true, "speed": 4, "curve": "easy", "style": "popin 80%" } },
--   "monitors":   { "desc:Samsung ...": { "mode": "2560x1440@200.00", "scale": 1 } } }
-- curves.json: the animation curves, for this file and the settings window's Animations page.

local json = require("json")

local dir = os.getenv("HOME") .. "/.config/hypr/"
local M = {}

local springs = {}
for _, c in ipairs(json.read(dir .. "curves.json") or {}) do
    if c.bezier then
        local b = c.bezier
        hl.curve(c.name, { type = "bezier", points = { { b[1], b[2] }, { b[3], b[4] } } })
    elseif c.spring then
        hl.curve(c.name, { type = "spring", mass = c.spring.mass, stiffness = c.spring.stiffness, damping = c.spring.damping })
        springs[c.name] = true
    end
end

-- "decoration:blur:size", 3 -> hl.config({ decoration = { blur = { size = 3 } } })
local function option(key, value)
    -- a plugin's options only exist once it's loaded (hyprland.lua runs again then)
    local plugin = key:match("^plugin:([^:]+):")
    if plugin and not hl.plugin[plugin] then return end
    local root = {}
    local node = root
    local parts = {}
    for part in key:gmatch("[^:]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        node[parts[i]] = {}
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
    hl.config(root)
end

local function animation(leaf, a)
    local spec = { leaf = leaf, enabled = a.enabled, speed = a.speed }
    if a.style and a.style ~= "" then spec.style = a.style end
    if springs[a.curve] then spec.spring = a.curve else spec.bezier = a.curve or "default" end
    hl.animation(spec)
end

local function monitor(output, m)
    hl.monitor({ output = output, mode = m.mode, position = m.position or "auto", scale = m.scale or "auto" })
end

function M.apply(s)
    for key, value in pairs(s.options or {}) do option(key, value) end
    for leaf, a in pairs(s.animations or {}) do animation(leaf, a) end
    for output, m in pairs(s.monitors or {}) do monitor(output, m) end
end

function M.apply_json(text)
    M.apply(assert(json.decode(text)))
end

-- settings.json, if there is one
function M.load()
    local f = io.open(dir .. "settings.json")
    if not f then return end
    local text = f:read("a")
    f:close()
    local s, err = json.decode(text)
    if not s then error("settings.json: " .. err) end
    M.apply(s)
end

return M
