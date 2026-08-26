vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "gruver16"

local c = {
  base00 = "#282828", base01 = "#302d2b", base02 = "#3c3836", base03 = "#7c6f64",
  base04 = "#a89984", base05 = "#dad2d1", base06 = "#e3dddc", base07 = "#ede9e8",
  base08 = "#fb4833", base09 = "#9e95c7", base0A = "#95a99f", base0B = "#8fbf7f",
  base0C = "#b3ccc0", base0D = "#96a6c8", base0E = "#d8a657", base0F = "#a5765c",
}
-- d1c7c5

local hl = vim.api.nvim_set_hl

hl(0, "Normal",       { fg = c.base05, bg = c.base00 })
hl(0, "NormalFloat",  { fg = c.base05, bg = c.base01 })
hl(0, "Cursor",       { fg = c.base00, bg = c.base05 })
hl(0, "CursorLine",   { bg = c.base01 })
hl(0, "CursorLineNr", { fg = c.base06 })
hl(0, "LineNr",       { fg = c.base04 })
hl(0, "Visual",       { bg = c.base02 })
hl(0, "Search",       { fg = c.base00, bg = c.base0A })
hl(0, "StatusLine",   { fg = c.base05, bg = c.base01 })
hl(0, "VertSplit",    { fg = c.base02 })
hl(0, "Pmenu",        { fg = c.base05, bg = c.base01 })
hl(0, "PmenuSel",     { fg = c.base00, bg = c.base0D })

hl(0, "Comment",      { fg = c.base03 })
hl(0, "Constant",     { fg = c.base09 })
hl(0, "String",       { fg = c.base0B })
hl(0, "Character",    { fg = c.base0B })
hl(0, "Number",       { fg = c.base09 })
hl(0, "Boolean",      { fg = c.base09 })
hl(0, "Identifier",   { fg = c.base05 })
hl(0, "Function",     { fg = c.base0D })
hl(0, "Statement",    { fg = c.base0E })
hl(0, "Keyword",      { fg = c.base0E })
hl(0, "Operator",     { fg = c.base05 })
hl(0, "PreProc",      { fg = c.base0C })
hl(0, "Type",         { fg = c.base0A })
hl(0, "Special",      { fg = c.base0C })
hl(0, "Underlined",   { fg = c.base0D, underline = true })
hl(0, "Error",        { fg = c.base08, bold = true })
hl(0, "Todo",         { fg = c.base0A, bg = c.base01, bold = true })

-- Treesitter (modern Neovim)
hl(0, "@variable",       { fg = c.base05 })
hl(0, "@function",       { fg = c.base0D })
hl(0, "@keyword",        { fg = c.base0E })
hl(0, "@string",         { fg = c.base0B })
hl(0, "@number",         { fg = c.base09 })
hl(0, "@type",           { fg = c.base0A })
hl(0, "@comment",        { fg = c.base03 })
hl(0, "@constant",       { fg = c.base0C })
hl(0, "@punctuation",    { fg = c.base05 })
