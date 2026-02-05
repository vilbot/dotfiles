local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux

local is_windows = wezterm.target_triple:find("window") ~= nil

local function split_current(direction)
    return wezterm.action_callback(function(window, pane)
        local proc = pane:get_foreground_process_name()
        
        local my_args = is_windows and { "pwsh.exe", "-NoLogo" } or { "/usr/bin/fish", "-li" }
        
        if is_windows and proc then
            proc_name = proc:lower()
            -- Check for CMD
            if proc_name:find("cmd.exe") then
                my_args = { "cmd.exe" }
                -- Check for PowerShell
            elseif proc_name:find("pwsh") or proc_name:find("powershell") then
                my_args = { "pwsh.exe", "-NoLogo" }
            end
        end

        pane:split({
            direction = direction,
            args = my_args,
            cwd = pane:get_current_working_dir() -- optional: keeps you in the same folder
        })
    end)
end

wezterm.on('gui-startup', function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
  local zoomed = ''
  if tab.active_pane.is_zoomed then
    zoomed = '[Z] '
  end

  local index = ''
  if #tabs > 1 then
    index = string.format('[%d/%d] ', tab.tab_index + 1, #tabs)
  end

  return zoomed .. index .. tab.active_pane.title
end)

local windows_launch_menu = {
    {
        label = "PowerShell",
        args = { "pwsh.exe", "-NoLogo" },
    },
    {
        label = "cmd",
        args = { "cmd.exe" },
    },
}

local my_keys = {
    { mods = 'CTRL|SHIFT', key = 'T', action = act.ShowLauncher },
    { mods = "LEADER", key = "h", action = act.ActivatePaneDirection "Left" },
    { mods = "LEADER", key = "l", action = act.ActivatePaneDirection "Right" },
    { mods = "LEADER", key = "k", action = act.ActivatePaneDirection "Up" },
    { mods = "LEADER", key = "j", action = act.ActivatePaneDirection "Down" },
    { mods = "LEADER", key = "w", action = act.CloseCurrentPane { confirm = true } },
}

if is_windows then
    -- Windows: Use the original function that worked
    table.insert(my_keys, { mods = "LEADER", key = "v", action = split_current("Right") })
    table.insert(my_keys, { mods = "LEADER", key = "s", action = split_current("Bottom") })
else
    -- Linux: Standard native splits (prevents the errors you saw)
    table.insert(my_keys, { mods = "LEADER", key = "v", action = act.SplitPane { direction = "Right", command = { domain = "CurrentPaneDomain" } } })
    table.insert(my_keys, { mods = "LEADER", key = "s", action = act.SplitPane { direction = "Down", command = { domain = "CurrentPaneDomain" } } })
end

return {
    default_prog = is_windows and { "pwsh.exe", "-NoLogo" } or { '/usr/bin/fish', '-li'},
    launch_menu = is_windows and windows_launch_menu or {},

    -- APPEARANCE
    font = wezterm.font {
        family = 'Liberation Mono',
    },

    font_size = 11.0,
    adjust_window_size_when_changing_font_size = false,

    color_scheme = 'Gruber (base16)',

    enable_tab_bar = false,
    window_decorations = "RESIZE|TITLE",
    window_padding = { left = 5, right = 5, top = 10, bottom = 0 },
    initial_rows = 40,
    initial_cols = 120,

    -- KEY BINDINGS
    leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 },
    
    keys = my_keys,
}
