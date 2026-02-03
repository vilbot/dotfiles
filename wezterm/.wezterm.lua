-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.

-- For example, changing the initial geometry for new windows:
config.initial_cols = 140
config.initial_rows = 36 

-- or, changing the font size and color scheme.
config.font = wezterm.font('Noto Sans Mono', {weight = 'Medium', italic = false})
config.font_size = 14
config.color_scheme = 'Kanagawa (Gogh)'
config.window_background_opacity = 0.85
config.win32_system_backdrop = 'Acrylic'
config.window_close_confirmation = 'NeverPrompt'

config.window_padding = {
  left = 10,
  right = 10,
  top = 0,
  bottom = 0,
}

config.window_decorations = "RESIZE"
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.show_close_tab_button_in_tabs = false
config.use_fancy_tab_bar = false

config.colors = {
  tab_bar = {
    -- Match your transparent background
    background = 'rgba(31, 31, 40, 0.85)',
    
    active_tab = {
      bg_color = '#7E9CD8',  -- Kanagawa blue
      fg_color = '#1F1F28',  -- Dark text for contrast
      intensity = 'Bold',
    },
    
    inactive_tab = {
      bg_color = 'rgba(42, 42, 55, 0.85)',  -- Slightly different from background
      fg_color = '#DCD7BA',  -- Kanagawa foreground
    },
    
    inactive_tab_hover = {
      bg_color = '#54546D',  -- Kanagawa gray
      fg_color = '#7E9CD8',  -- Blue text on hover
    },
    
    new_tab = {
      bg_color = 'rgba(31, 31, 40, 0.85)',
      fg_color = '#DCD7BA',
    },
    
    new_tab_hover = {
      bg_color = '#54546D',
      fg_color = '#7E9CD8',
    },
  },
}

config.keys = {
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.DisableDefaultAssignment,
  }
}

config.default_prog = {'pwsh.exe'}

-- Finally, return the configuration to wezterm:
return config
