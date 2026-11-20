-- What the Settings app (tty/settings) changed of Hyprland's options: tty/settings.json, written
-- only by it, applied over hyprland.lua's own values (tty/hyprland.lua requires this last).
-- The app also sends each change here while you drag a slider:
--   hyprctl eval 'NoneOptions.apply_json([==[{"input:repeat_rate": 30}]==])'
-- settings.json: { "input:repeat_rate": 30, "cursor:hide_on_key_press": true, ... }

local json = require("json")
local M = {}

-- "input:repeat_rate", 30 -> hl.config({ input = { repeat_rate = 30 } })
local function option(key, value)
    local root, node, parts = {}, nil, {}
    for part in key:gmatch("[^:]+") do parts[#parts + 1] = part end
    node = root
    for i = 1, #parts - 1 do
        node[parts[i]] = {}
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
    hl.config(root)
end

function M.apply(options)
    for key, value in pairs(options) do option(key, value) end
end

function M.apply_json(text)
    M.apply(assert(json.decode(text)))
end

function M.load(path)
    M.apply(json.read(path) or {})
end

return M
