local wezterm = require 'wezterm'
local act = wezterm.action

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

return {
    default_prog = { '/usr/bin/fish', '-li'},

    -- Colorscheme
    color_scheme = 'Gruber (base16)',
    -- color_scheme = 'Vesper',

    -- Fonts
    font = wezterm.font {
        -- family = 'Liberation Mono',
        family = 'DroidSansMonoSlashed',
        -- family = 'Noto Sans Mono',
        -- family = 'IBM Plex Mono',
        -- family = 'JetBrains Mono',
        -- family = 'Ubuntu Mono',
    },
    font_size = 11.0,
    adjust_window_size_when_changing_font_size = false,

    -- Window and tabs
    window_padding = { left = 5, right = 5, top = 10, bottom = 0 },
    initial_rows = 40,
    initial_cols = 120,
    window_decorations = "RESIZE|TITLE",

    enable_tab_bar = true,
    use_fancy_tab_bar = true,
    show_close_tab_button_in_tabs = false,
    show_new_tab_button_in_tab_bar = false,

    window_frame = {
        active_titlebar_bg = '#181818',
        inactive_titlebar_bg = '#181818',
    },

    -- Keybinds
    leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 },

    keys = {
        { mods = "LEADER", key = "h", action = act.ActivatePaneDirection "Left" },
        { mods = "LEADER", key = "l", action = act.ActivatePaneDirection "Right" },
        { mods = "LEADER", key = "k", action = act.ActivatePaneDirection "Up" },
        { mods = "LEADER", key = "j", action = act.ActivatePaneDirection "Down" },
        { mods = "LEADER", key = "w", action = act.CloseCurrentPane { confirm = true } },
        { mods = "LEADER", key = "v", action = act.SplitPane { direction = "Right" } },
        { mods = "LEADER", key = "s", action = act.SplitPane { direction = "Down" } },
    },
}
