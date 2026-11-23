-- The palette util/colorscheme.lua draws with: `name`'s own (palettes/<name>.lua, generated), or
-- on the "None" desktop the theme picked there. None sets $NONE_THEME to its theme file (JSON
-- with base00..base0F as "#rrggbb", and "variant" = "dark" | "light") and, when the theme
-- changes, fires `User NoneTheme` in every nvim: config/autocmds.lua loads the colorscheme again
-- (which reads this again).
-- Usage: require("palettes.current")(name); without a name, the running colorscheme's.

-- `color` at `alpha` (0-255) over the background, as Zed draws its see-through colors
local function over(c, color, alpha)
  local function ch(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
  local out = "#"
  for _, i in ipairs({ 2, 4, 6 }) do
    out = out .. string.format("%02x", math.floor(ch(c.base00, i) + (ch(color, i) - ch(c.base00, i)) * alpha / 255 + 0.5))
  end
  return out
end

return function(name)
  local file = vim.env.NONE_THEME
  if file and file ~= "" then
    local ok, t = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
    end)
    if ok and type(t) == "table" and t.base00 then
      -- None's themes carry no blend colors: the same alphas as theme/templates/zed.json
      t.blend = t.blend or {
        active_line = over(t, t.base01, 0xbf),  -- editor.active_line.background
        selection = over(t, t.base0D, 0x3d),    -- players[0].selection
        match = over(t, t.base0D, 0x66),        -- search.match_background
        active_match = over(t, t.base0E, 0x66), -- search.active_match_background
      }
      return t
    end
  end
  name = name or vim.g.colors_name or "gruver16"
  local mod = "palettes." .. name
  if not pcall(require, mod) then mod = "palettes.gruver16" end
  package.loaded[mod] = nil -- pick up a fresh build on :colorscheme
  return vim.tbl_extend("force", { variant = "dark" }, require(mod))
end
