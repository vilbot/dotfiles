-- Desktop actions by name. Keys are bound in keys/remap.toml; mackeys runs an action with
-- `hyprctl eval 'Actions["window.close"]()'`. hyprland.lua makes the table global:
--   Actions = require("actions")({ programs = programs, desktops = 5 })

return function(opts)
    local P, N = opts.programs, opts.desktops
    local A = {}
    local function run(dispatcher) return function() hl.dispatch(dispatcher) end end
    local function exec(cmd) return run(hl.dsp.exec_cmd(cmd)) end

    -- Desktops 1..N, wrapping around like KDE (Hyprland's relative workspaces don't stop at N).
    local function step(delta)
        local id = (hl.get_active_workspace() or {}).id or 1
        return (id - 1 + delta) % N + 1
    end
    for n = 1, N do
        A["desktop.goto." .. n] = run(hl.dsp.focus({ workspace = n }))
        A["desktop.move." .. n] = run(hl.dsp.window.move({ workspace = n, follow = false })) -- you stay
        A["desktop.take." .. n] = run(hl.dsp.window.move({ workspace = n, follow = true }))
    end
    A["desktop.next"] = function() hl.dispatch(hl.dsp.focus({ workspace = step(1) })) end
    A["desktop.prev"] = function() hl.dispatch(hl.dsp.focus({ workspace = step(-1) })) end
    A["desktop.move.next"] = function() hl.dispatch(hl.dsp.window.move({ workspace = step(1), follow = false })) end
    A["desktop.move.prev"] = function() hl.dispatch(hl.dsp.window.move({ workspace = step(-1), follow = false })) end
    A["desktop.last"] = run(hl.dsp.focus({ workspace = "previous" }))
    A["scratchpad.toggle"] = run(hl.dsp.workspace.toggle_special("scratchpad"))
    A["scratchpad.move"] = run(hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

    -- Windows
    local resize = { left = { -60, 0 }, down = { 0, 60 }, up = { 0, -60 }, right = { 60, 0 } }
    for dir, xy in pairs(resize) do
        A["window.focus." .. dir] = run(hl.dsp.focus({ direction = dir }))
        A["window.move." .. dir] = run(hl.dsp.window.move({ direction = dir }))
        A["window.swap." .. dir] = run(hl.dsp.window.swap({ direction = dir }))
        A["window.resize." .. dir] = run(hl.dsp.window.resize({ x = xy[1], y = xy[2], relative = true }))
    end
    A["window.close"] = run(hl.dsp.window.close())
    A["window.fullscreen"] = run(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    A["window.maximize"] = run(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    A["window.float"] = run(hl.dsp.window.float({ action = "toggle" }))
    A["window.pin"] = run(hl.dsp.window.pin())
    A["window.center"] = run(hl.dsp.window.center())
    A["window.split"] = run(hl.dsp.layout("togglesplit"))
    A["group.toggle"] = run(hl.dsp.group.toggle())
    A["group.next"] = run(hl.dsp.group.next())
    A["group.prev"] = run(hl.dsp.group.prev())

    -- App switcher (quickshell/AppSwitcher.qml). mackeys runs commit when Cmd is let go.
    for _, name in ipairs({ "next", "prev", "windows", "windows-prev", "commit" }) do
        A["app.switch." .. name:gsub("-", ".")] = run(hl.dsp.global("quickshell:switcher-" .. name))
    end

    -- Launching
    A["launcher"] = exec(P.launcher)
    A["launcher.alt"] = exec(P.launcher_alt)
    A["terminal"] = exec(P.terminal)
    A["layout.next"] = exec("hyprctl switchxkblayout all next")
    -- HyprCapture once that plugin is loaded, else hypr/screenshot.sh
    A["screenshot.region"] = function()
        if hl.plugin and hl.plugin.hyprcapture then hl.plugin.hyprcapture.open()
        else hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh")) end
    end

    -- Mission control (the hymission plugin; nothing happens until it's loaded).
    -- This desktop: no search box; the mouse and the selection move real focus. The search box opens
    -- by itself unless pick labels are on, so they're on but hidden (1-9 pick a window, / searches).
    -- All desktops: the search box is ready. It holds the keyboard, so the selection can't follow
    -- the mouse (it would jump back to the window under the pointer after every arrow press).
    local function overview(scope, labels, follow)
        return function()
            local hm = hl.plugin and hl.plugin.hymission
            if not hm then return end
            hl.config({ plugin = { hymission = { pick_labels_enabled = labels, pick_labels_show = 0,
                overview_focus_follows_mouse = follow } } })
            hm.toggle(scope)
        end
    end
    A["overview.desktop"] = overview("onlycurrentworkspace", 1, 1)
    A["overview.all"] = overview("forceall", 0, 0)
    -- Switching desktop inside mission control also picks the new desktop's leftmost window, once
    -- hymission's switch is done (it takes 180 ms, then focuses that desktop's last-used window).
    local function focus_leftmost(ws)
        hl.timer(function()
            local best
            for _, w in ipairs(hl.get_workspace_windows(ws) or {}) do
                local x = type(w.at) == "table" and w.at.x or 0
                if not w.hidden and (not best or x < best.x) then best = { x = x, address = w.address } end
            end
            if best then hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address })) end
        end, { timeout = 250, type = "oneshot" })
    end
    for name, delta in pairs({ next = 1, prev = -1 }) do
        A["overview.desktop." .. name] = function()
            local n = step(delta)
            hl.dispatch(hl.dsp.focus({ workspace = n }))
            focus_leftmost(n)
        end
    end

    -- Function keys
    A["brightness.down"] = exec("qs ipc call brightness down") -- quickshell/CcDisplay.qml
    A["brightness.up"] = exec("qs ipc call brightness up")
    A["appearance.toggle"] = exec("~/.config/hypr/appearance.sh toggle")
    A["media.back"] = exec("playerctl position 5-")
    A["media.playpause"] = exec("playerctl play-pause")
    A["media.forward"] = exec("playerctl position 5+")
    A["media.next"] = exec("playerctl next")
    A["media.prev"] = exec("playerctl previous")
    A["volume.mute"] = exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    A["volume.down"] = exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    A["volume.up"] = exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")

    -- Quickshell panels
    A["panel.control"] = exec("qs ipc call controlcenter toggle")
    A["panel.notifications"] = exec("qs ipc call notifications toggle")
    A["panel.settings"] = exec("qs ipc call settings toggle")
    A["help.keys"] = exec("qs ipc call keybinds toggle")

    -- Session
    A["session.reload"] = run(hl.dsp.reload_config())
    A["session.exit"] = run(hl.dsp.exit())

    return A
end
