local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local current_font = wezterm.font {
    family = 'Droid Sans Mono Slashed',
    -- family = 'Noto Sans Mono',
    -- family = 'Liberation Mono',
    -- family = 'IBM Plex Mono',
    -- family = 'Hack',
    -- family = 'Iosevka'
    -- family = 'JetBrains Mono',
    -- family = 'Ubuntu Mono',
}

-- config.default_prog = { '/usr/bin/fish', '-li'}
config.default_prog = { 'pwsh.exe', '-NoLogo'}

-- Colorscheme
config.color_scheme = 'Gruber (base16)'
-- config.color_scheme = 'Vesper'

-- Fonts
config.font = current_font
config.font_size = 11.0
config.adjust_window_size_when_changing_font_size = false

-- Window and tabs
config.window_padding = { left = 5, right = 5, top = 10, bottom = 0 }
config.initial_rows = 40
config.initial_cols = 120
config.window_decorations = "RESIZE|TITLE"
config.window_frame = {
    inactive_titlebar_bg = '#181818',
    active_titlebar_bg = '#282828',
    font_size = 10,
    font = current_font
}
config.colors = {
    tab_bar = {
        inactive_tab_edge = '#282828', -- for fancy tab bar
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

    local background = '#282828'
    local foreground = '#a0a0a0'

    if tab.is_active then
        background = '#181818'
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
}

return config
