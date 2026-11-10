vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "custom"

local c = require("palettes.gruver16")
local hl = vim.api.nvim_set_hl

-- Zed's alpha colors, flattened over the editor background
local blend = {
  active_line = "#303134", -- editor.active_line.background
  selection = "#42464e",   -- players[0].selection
  match = "#545a68",       -- search.match_background
  active_match = "#6e5a3b", -- search.active_match_background
}

hl(0, "Normal",         { fg = c.base07, bg = c.base00 })
hl(0, "NormalFloat",    { fg = c.base07, bg = c.base00 })
hl(0, "FloatBorder",    { bg = c.base00 })
hl(0, "Cursor",         { fg = c.base00, bg = c.base0D })
hl(0, "CursorLine",     { bg = blend.active_line })
hl(0, "CursorLineNr",   { fg = c.base07 })
hl(0, "LineNr",         { fg = c.base04 })
hl(0, "Visual",         { bg = blend.selection })
hl(0, "Search",         { bg = blend.match })
hl(0, "CurSearch",      { bg = blend.active_match })
hl(0, "IncSearch",      { bg = blend.active_match })
hl(0, "StatusLine",     { fg = c.base07, bg = c.base02 })
hl(0, "VertSplit",      { fg = c.base02 })
hl(0, "WinSeparator",   { fg = c.base02, bg = c.base00 })
hl(0, "Pmenu",          { fg = c.base07, bg = c.base01 })
hl(0, "PmenuSel",       { fg = c.base00, bg = c.base0D })
hl(0, "YankHighlight",  { fg = c.base00, bg = c.base0E })
hl(0, "Directory",      { fg = c.base0D, bg = c.base00 })
hl(0, "MatchParen",     { bg = c.base03, bold = true })

hl(0, "DiagnosticError", { fg = c.base08 })
hl(0, "DiagnosticWarn",  { fg = c.base0E })
hl(0, "DiagnosticInfo",  { fg = c.base0D })
hl(0, "DiagnosticHint",  { fg = c.base0C })

-- Vim's regex syntax groups, for file types without a treesitter parser
hl(0, "Comment",        { fg = c.base03 })
hl(0, "Constant",       { fg = c.base0C })
hl(0, "String",         { fg = c.base0B })
hl(0, "Character",      { fg = c.base0B })
hl(0, "Number",         { fg = c.base09 })
hl(0, "Boolean",        { fg = c.base09 })
hl(0, "Identifier",     { fg = c.base07 })
hl(0, "Function",       { fg = c.base0D })
hl(0, "Statement",      { fg = c.base0E })
hl(0, "Keyword",        { fg = c.base0E })
hl(0, "Operator",       { fg = c.base07 })
hl(0, "PreProc",        { fg = c.base0C })
hl(0, "Type",           { fg = c.base0A })
hl(0, "Special",        { fg = c.base0C })
hl(0, "Tag",            { fg = c.base0D })
hl(0, "Delimiter",      { fg = c.base07 })
hl(0, "Title",          { fg = c.base0E, bold = true })
hl(0, "Underlined",     { fg = c.base0D, underline = true })
hl(0, "Error",          { fg = c.base08, bold = true })
hl(0, "Todo",           { fg = c.base00, bg = c.base08, bold = true })

-- The "syntax" block of zed/themes/gruver16.json. Zed and Neovim both resolve a capture
-- like @keyword.import by its longest listed prefix, so these names carry over as they are.
local syntax = {
  ["attribute"]               = { fg = c.base0D },
  ["attribute.annotation"]    = { fg = c.base0C },
  ["boolean"]                 = { fg = c.base09 },
  ["comment"]                 = { fg = c.base03 },
  ["comment.doc"]             = { fg = c.base04 },
  ["constant"]                = { fg = c.base0C },
  ["constructor"]             = { fg = c.base0D },
  ["embedded"]                = { fg = c.base0C },
  ["emphasis"]                = { fg = c.base0D },
  ["emphasis.strong"]         = { fg = c.base0D, bold = true },
  ["enum"]                    = { fg = c.base0E },
  ["function"]                = { fg = c.base0D },
  ["function.builtin"]        = { fg = c.base08 },
  ["hint"]                    = { fg = c.base0C },
  ["keyword"]                 = { fg = c.base0E },
  ["label"]                   = { fg = c.base0D },
  ["link_text"]               = { fg = c.base0B },
  ["link_uri"]                = { fg = c.base09 },
  ["namespace"]               = { fg = c.base0D },
  ["number"]                  = { fg = c.base09 },
  ["operator"]                = { fg = c.base07 },
  ["predictive"]              = { fg = c.base03 },
  ["preproc"]                 = { fg = c.base0C },
  ["primary"]                 = { fg = c.base07 },
  ["property"]                = { fg = c.base07 },
  ["punctuation"]             = { fg = c.base07 },
  ["punctuation.bracket"]     = { fg = c.base05 },
  ["punctuation.delimiter"]   = { fg = c.base07 },
  ["punctuation.list_marker"] = { fg = c.base07 },
  ["punctuation.markup"]      = { fg = c.base0D },
  ["punctuation.special"]     = { fg = c.base0C },
  ["selector"]                = { fg = c.base0E },
  ["selector.pseudo"]         = { fg = c.base0D },
  ["string"]                  = { fg = c.base0B },
  ["string.escape"]           = { fg = c.base0C },
  ["string.regex"]            = { fg = c.base0E },
  ["string.special"]          = { fg = c.base09 },
  ["string.special.symbol"]   = { fg = c.base0B },
  ["tag"]                     = { fg = c.base0D },
  ["text.literal"]            = { fg = c.base0B },
  ["title"]                   = { fg = c.base0E, bold = true },
  ["type"]                    = { fg = c.base0A },
  ["variable"]                = { fg = c.base07 },
  ["variable.parameter"]      = { fg = c.base07 },
  ["variable.special"]        = { fg = c.base09 },
  ["variant"]                 = { fg = c.base0D },
  ["diff.plus"]               = { fg = c.base0B },
  ["diff.minus"]              = { fg = c.base08 },
}
for name, style in pairs(syntax) do
  hl(0, "@" .. name, style)
end

-- Neovim links these to its own groups by default, which would beat the prefix match above.
-- Captures with no key in Zed's theme render as plain text there.
local plain = { fg = c.base07 }
for name, style in pairs({
  ["attribute.builtin"]         = syntax["attribute"],
  ["character"]                 = syntax["string"],
  ["character.special"]         = syntax["string.special"],
  ["comment.error"]             = syntax["comment"],
  ["comment.note"]              = syntax["comment"],
  ["comment.todo"]              = syntax["comment"],
  ["comment.warning"]           = syntax["comment"],
  ["constant.builtin"]          = syntax["constant"],
  ["diff.delta"]                = syntax["enum"],
  ["keyword.operator"]          = syntax["keyword"],
  ["module"]                    = plain,
  ["module.builtin"]            = plain,
  ["number.float"]              = syntax["number"],
  ["string.regexp"]             = syntax["string.regex"],
  ["string.special.url"]        = syntax["link_uri"],
  ["tag.builtin"]               = syntax["tag"],
  ["type.builtin"]              = syntax["type"],
  ["variable.builtin"]          = syntax["variable"],
  ["variable.parameter.builtin"] = syntax["variable.parameter"],
  ["concept"]                   = plain,
  ["text.jsx"]                  = plain,

  -- nvim-treesitter's names for Zed's markup keys, used by its markdown and vimdoc queries
  ["markup"]                    = syntax["primary"],
  ["markup.heading"]            = syntax["title"],
  ["markup.heading.1.delimiter.vimdoc"] = syntax["title"],
  ["markup.heading.2.delimiter.vimdoc"] = syntax["title"],
  ["markup.italic"]             = { fg = c.base0D, italic = true },
  ["markup.link"]               = syntax["link_text"],
  ["markup.link.url"]           = syntax["link_uri"],
  ["markup.list"]               = syntax["punctuation.list_marker"],
  ["markup.raw"]                = syntax["text.literal"],
  ["markup.strikethrough"]      = { strikethrough = true },
  ["markup.strong"]             = syntax["emphasis.strong"],
  ["markup.underline"]          = { underline = true },
}) do
  hl(0, "@" .. name, style)
end

hl(0, "FoldColumn",         { fg = c.base03, bg = "NONE" })
hl(0, "Folded",             { fg = c.base07, bg = c.base01 })
hl(0, "UfoFoldedBg",        { bg = c.base02 })
hl(0, "BlinkCmpMenu",       { bg = c.base00 })
hl(0, "BlinkCmpMenuBorder", { bg = c.base00 })
hl(0, "BlinkCmpDoc",        { bg = c.base00 })
hl(0, "BlinkCmpDocBorder",  { bg = c.base00 })

hl(0, 'cTypeQualifier',             { link = 'Keyword' })
hl(0, "cTypedef",                   { link = 'Keyword' })
hl(0, "cStructure",                 { link = 'Keyword' })
hl(0, "cppStatement",               { link = 'Keyword' })

hl(0, "GitSignsAdd",    { bg = c.base00, fg = c.base0B, bold = false })
hl(0, "GitSignsDelete", { bg = c.base00, fg = c.base08, bold = false })
hl(0, "GitSignsChange", { bg = c.base00, fg = c.base0E, bold = false })
