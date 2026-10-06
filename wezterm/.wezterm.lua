local wezterm = require 'wezterm'
local palette = dofile('/Users/vilgot/dotfiles/nvim/lua/palettes/gruver16.lua')
local act = wezterm.action
local config = wezterm.config_builder()
config.color_scheme_dirs = { '/Users/vilgot/dotfiles/wezterm/colors' }

config.color_scheme = 'gruver16'

local current_font = wezterm.font 
{
    family = 'Droid Sans Mono Slashed',
    -- family = 'Consolas',
	-- family = 'Liberation Mono',
    -- family = 'Fira Code',
    -- family = 'Ac437 PhoenixEGA 8x14',
    -- family = 'JetBrains Mono',
    -- family = 'Courier new'
    harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' },
}

-- Fonts
config.font = current_font
config.font_size = 16.0
config.adjust_window_size_when_changing_font_size = false
config.line_height = 1.35
-- config.cell_width = 1.0

-- Window and tabs
config.window_padding = { left = 5, right = 5, top = 10, bottom = 0 }
config.initial_rows = 30
config.initial_cols = 100
config.window_decorations = "RESIZE|INTEGRATED_BUTTONS" -- |TITLE"
config.integrated_title_button_style = "MacOsNative"
config.window_frame = {
    active_titlebar_bg = palette.base01,
	inactive_titlebar_bg = palette.base00, -- not needed
    font_size = 10,
    font = current_font
}
config.colors = {
    tab_bar = {
		inactive_tab_edge = palette.base01, -- for fancy tab bar
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

    local background = palette.base01
    local foreground = palette.base04

    if tab.is_active then
        background = palette.base00
        foreground = palette.base05
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
