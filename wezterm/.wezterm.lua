local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.default_prog = { 'pwsh.exe', '-NoLogo'}

config.launch_menu = {
  {
    label = 'VS 2022 Developer PowerShell',
    args = {
      'pwsh.exe',
      '-NoExit',
      '-Command',
      -- Replace the path if you use Pro/Enterprise or a different version
      -- Replace <YourInstanceID> with your specific VS instance ID
      '&{Import-Module "C:\\Program Files\\Microsoft Visual Studio\\18\\Community\\Common7\\Tools\\Microsoft.VisualStudio.DevShell.dll"; Enter-VsDevShell e21d14fb}'
    },
  },
}

-- Colorscheme
-- config.color_scheme = 'Gruber (base16)'
-- config.color_scheme = 'Vesper'
-- config.color_scheme = 'Tender (Gogh)'

local nord = wezterm.color.get_builtin_schemes()['nord']
nord.background = '#242933'

config.color_schemes = { ['nord-custom'] = nord }
config.color_scheme = 'nord-custom'
-- config.color_scheme = 'nord'

local current_font = wezterm.font 
{
    -- family = 'Droid Sans Mono Slashed',
    -- family = 'Consolas',
    -- family = 'Liberation Mono',
    family = 'JetBrains Mono',
    harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' },
}

-- Fonts
config.font = current_font
config.font_rules = {
    {
        italic = true,
        intensity = 'Normal',
        font = wezterm.font {
            family = 'JetBrains Mono',
            style = 'Normal',
            harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' },
        },
    },
    {
        italic = true,
        intensity = 'Bold',
        font = wezterm.font {
            family = 'JetBrains Mono',
            style = 'Normal',
            weight = 'Bold',
            harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' },
        },
    },
}
config.font_size = 12.0
config.adjust_window_size_when_changing_font_size = false

-- Window and tabs
config.window_padding = { left = 5, right = 5, top = 10, bottom = 0 }
config.initial_rows = 40
config.initial_cols = 120
config.window_decorations = "RESIZE"
config.window_frame = {
    active_titlebar_bg = '#2e3440',
    -- inactive_titlebar_bg = '#282828', -- not needed
    font_size = 10,
    font = current_font
}
config.colors = {
    tab_bar = {
        inactive_tab_edge = '#2e3440', -- for fancy tab bar
    }
}

config.enable_tab_bar = true
config.use_fancy_tab_bar = true
config.show_close_tab_button_in_tabs = false
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = false
config.tab_max_width = 100

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
    local title = tab.active_pane.title:gsub(" %((.*)%) %- (.*)", "")

    local background = '#2e3440'
    local foreground = '#a0a0a0'

    if tab.is_active then
        background = nord.background
        foreground = '#d0d0d0'
    end

    return {
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = " " .. title .. " "},
    }
end)

-- Keybinds
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
    { mods = "LEADER", key = "w", action = act.CloseCurrentPane { confirm = true } },
    { mods = "LEADER", key = "v", action = act.SplitPane { direction = "Right" } },
    { mods = "LEADER", key = "s", action = act.SplitPane { direction = "Down" } },
    { mods = "ALT", key = "H", action = act.AdjustPaneSize { "Left", 1 } },
    { mods = "ALT", key = "L", action = act.AdjustPaneSize { "Right", 1 } },
    { mods = "ALT", key = "K", action = act.AdjustPaneSize { "Up", 1 } },
    { mods = "ALT", key = "J", action = act.AdjustPaneSize { "Down", 1 } },
    { mods = "LEADER", key = "h", action = act.ActivatePaneDirection "Left" },
    { mods = "LEADER", key = "l", action = act.ActivatePaneDirection "Right" },
    { mods = "LEADER", key = "k", action = act.ActivatePaneDirection "Up" },
    { mods = "LEADER", key = "j", action = act.ActivatePaneDirection "Down" },
    { mods = 'CTRL', key = 'L', action = wezterm.action.ShowLauncher },
}

return config
