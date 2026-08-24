local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local current_font = wezterm.font {
    family = 'Droid Sans Mono Slashed',
    -- family = 'Fira Code',
    -- family = 'Ac437 PhoenixEGA 8x14',
    -- family = 'Liberation Mono',
    -- family = 'JetBrains Mono',
    -- family = 'Courier new'
}

-- Fonts
config.font = current_font
config.font_size = 14.0
config.adjust_window_size_when_changing_font_size = false
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- Colorscheme
config.color_scheme = 'Gruber (base16)'
-- config.color_scheme = 'Vesper'
-- config.color_scheme = 'Tender (Gogh)'
-- config.color_scheme = 'Gruvbox Dark (Gogh)'


-- Window and tabs
config.window_padding = { left = 5, right = 5, top = 10, bottom = 0 }
config.initial_rows = 30
config.initial_cols = 100
config.window_decorations = "RESIZE|INTEGRATED_BUTTONS" -- |TITLE"
config.integrated_title_button_style = "MacOsNative"
config.window_frame = {
    active_titlebar_bg = '#181818',
    -- inactive_titlebar_bg = '#282828', -- not needed
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

    local background = '#181818'
    local foreground = '#909090'
    local tab_opening = "   "
    local tab_closing = "   "

    if tab.is_active then
        -- background = '#282828'
        foreground = '#f0f0f0'
        tab_opening = "   "
        tab_closing = "   "
    end

    return {
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = tab_opening .. title .. tab_closing},
    }
end)

-- Keybinds
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

config.keys = {
    { mods = "LEADER", key = "w", action = act.CloseCurrentPane { confirm = true } },
    { mods = "LEADER", key = "v", action = act.SplitPane { direction = "Right" } },
    { mods = "LEADER", key = "s", action = act.SplitPane { direction = "Down" } },
    { mods = "OPT", key = "H", action = act.AdjustPaneSize { "Left", 1 } },
    { mods = "OPT", key = "L", action = act.AdjustPaneSize { "Right", 1 } },
    { mods = "OPT", key = "K", action = act.AdjustPaneSize { "Up", 1 } },
    { mods = "OPT", key = "J", action = act.AdjustPaneSize { "Down", 1 } },
    { mods = "LEADER", key = "h", action = act.ActivatePaneDirection "Left" },
    { mods = "LEADER", key = "l", action = act.ActivatePaneDirection "Right" },
    { mods = "LEADER", key = "k", action = act.ActivatePaneDirection "Up" },
    { mods = "LEADER", key = "j", action = act.ActivatePaneDirection "Down" },
}

return config
