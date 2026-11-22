-- The None desktop's actions by name. Their keys are in tty/keys.json, bound by tty/binds.lua;
-- by hand: `hyprctl eval 'Actions["window.close"]()'`. tty/hyprland.lua makes the table global:
--   Actions = require("actions")({ tty = tty, programs = programs, desktops = 5 })

return function(opts)
    local P, N, tty = opts.programs, opts.desktops, opts.tty
    local A = {}
    local function run(dispatcher) return function() hl.dispatch(dispatcher) end end
    local function exec(cmd) return run(hl.dsp.exec_cmd(cmd)) end
    local shell = "qs -p " .. tty .. "shell ipc call "   -- None's shell (tty/shell)

    -- Desktops 1..N, wrapping around (Hyprland's relative workspaces don't stop at N).
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

    -- Universal clipboard (as in Omarchy): Super+C/V/X copy, paste and cut in every app, terminals
    -- too (tty/foot.ini: Ctrl+Insert copies, Shift+Insert pastes), so Ctrl+C stays the app's own
    local function shortcut(mods, key) return run(hl.dsp.send_shortcut({ mods = mods, key = key })) end
    A["clipboard.copy"] = shortcut("CTRL", "Insert")
    A["clipboard.paste"] = shortcut("SHIFT", "Insert")
    A["clipboard.cut"] = shortcut("CTRL", "X")

    -- Launching
    A["launcher"] = exec(P.launcher)
    A["terminal"] = exec(P.terminal)
    A["settings"] = exec(tty .. "settings.sh")                       -- the Settings app (tty/settings)
    A["help.keys"] = exec(tty .. "settings.sh shortcuts")
    A["layout.next"] = exec("hyprctl switchxkblayout all next")
    A["screenshot.region"] = exec(tty .. "bin/screenshot")

    -- Function keys
    A["brightness.down"] = exec(shell .. "brightness down")
    A["brightness.up"] = exec(shell .. "brightness up")
    A["appearance.toggle"] = exec(tty .. "appearance.sh toggle")
    A["media.back"] = exec("playerctl position 5-")
    A["media.playpause"] = exec("playerctl play-pause")
    A["media.forward"] = exec("playerctl position 5+")
    A["media.next"] = exec("playerctl next")
    A["media.prev"] = exec("playerctl previous")
    A["volume.mute"] = exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    A["volume.down"] = exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    A["volume.up"] = exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
    A["panel.control"] = exec(tty .. "panel.sh")                     -- the control center (F5)

    -- Session. Logout ends None: greetd shows the login screen again (tty/greeter)
    A["session.reload"] = run(hl.dsp.reload_config())
    A["session.exit"] = run(hl.dsp.exit())
    A["session.lock"] = exec(P.lock)
    A["session.sleep"] = exec(P.sleep)

    return A
end
