-- The palette colors/custom.lua draws with: gruver16 (palettes/gruver16.lua, generated), or on
-- the "None" desktop the theme picked there. None sets $NONE_THEME to its theme file (JSON with
-- base00..base0F as "#rrggbb", and "variant" = "dark" | "light") and, when the theme changes,
-- fires `User NoneTheme` in every nvim: config/autocmds.lua loads the colorscheme again (which
-- reads this again).
local file = vim.env.NONE_THEME
if file and file ~= "" then
  local ok, t = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
  end)
  if ok and type(t) == "table" and t.base00 then
    return t
  end
end
return vim.tbl_extend("force", { variant = "dark" }, require("palettes.gruver16"))
