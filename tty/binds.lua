-- None's keys as Hyprland binds: every desktop key in tty/keys.json runs its action from
-- tty/actions.lua. Plain Linux keys: nothing is remapped, apps get every key that isn't bound here
-- (the physical Cmd key is Super, which apps don't use, so desktop keys never collide with them).
--   require("binds")(Actions, tty .. "keys.json")
-- An action keys.json names that actions.lua doesn't have is an error (Hyprland --verify-config
-- shows it: tty/check.sh).

local json = require("json")

local templates = {
    ["{dir}"] = { { "H", "left" }, { "J", "down" }, { "K", "up" }, { "L", "right" } },
    ["{arrow}"] = { { "Left", "left" }, { "Down", "down" }, { "Up", "up" }, { "Right", "right" } },
}

-- "SUPER + {dir}" for "window.focus.{dir}" -> { {"SUPER + H", "window.focus.left"}, ... }
local function expand(keys, action, desktops)
    if action:find("{n}", 1, true) or keys:find("{n}", 1, true) then
        local out = {}
        for n = 1, desktops do
            out[#out + 1] = { (keys:gsub("{n}", n)), (action:gsub("{n}", n)) }
        end
        return out
    end
    for name, list in pairs(templates) do
        if keys:find(name, 1, true) then
            local out = {}
            for _, t in ipairs(list) do
                out[#out + 1] = { keys:gsub(name, t[1]), (action:gsub("{dir}", t[2])) }
            end
            return out
        end
    end
    return { { keys, action } }
end

-- the "record" submap: no binds, so the Settings app's Shortcuts page gets every key while it
-- records one (tty/settings/Keymap.qml switches to it and back). The old emergency key resets it
-- if the app went away mid-recording.
local function record_submap()
    hl.define_submap("none-record", function()
        hl.bind("CTRL + ALT + SUPER + Return", hl.dsp.submap("reset"))
    end)
end

return function(actions, file)
    local keys, err = json.read(file)
    if not keys then error("tty/keys.json: " .. tostring(err)) end
    local desktops = keys.desktops or 5

    for _, section in ipairs(keys.sections or {}) do
        for action, def in pairs(section.actions or {}) do
            for _, k in ipairs(def.keys or {}) do
                for _, b in ipairs(expand(k, action, desktops)) do
                    local fn = actions[b[2]]
                    if not fn then error("tty/keys.json: no action " .. b[2] .. " in tty/actions.lua") end
                    hl.bind(b[1], fn, { repeating = def["repeat"] == true, description = def.label })
                end
            end
        end
    end

    -- right Alt (AltGr, lv3:ralt_switch) + F-key: the plain F-key, for the app (the bare ones are
    -- the actions printed on the keys)
    for n = 1, 12 do
        hl.bind("MOD5 + F" .. n, hl.dsp.send_shortcut({ mods = "", key = "F" .. n }))
        hl.bind("MOD5 + SHIFT + F" .. n, hl.dsp.send_shortcut({ mods = "SHIFT", key = "F" .. n }))
    end

    -- mouse: Super + left-drag moves a window, Super + right-drag resizes it
    hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- media keys (headsets, other keyboards)
    local media = {
        XF86AudioPlay = "media.playpause", XF86AudioPause = "media.playpause", XF86AudioNext = "media.next",
        XF86AudioPrev = "media.prev", XF86AudioMute = "volume.mute", XF86AudioLowerVolume = "volume.down",
        XF86AudioRaiseVolume = "volume.up", XF86MonBrightnessDown = "brightness.down",
        XF86MonBrightnessUp = "brightness.up",
    }
    for key, action in pairs(media) do
        hl.bind(key, actions[action], { locked = true, repeating = action:find("%.down$") ~= nil or action:find("%.up$") ~= nil })
    end

    record_submap()
    return desktops
end
