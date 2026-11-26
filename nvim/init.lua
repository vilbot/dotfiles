vim.loader.enable()

require("config.options") -- leader and options: must run before plugins load
require("config.lazy")    -- plugin manager, imports every file in lua/plugins/
require("config.autocmds")
require("config.keymaps")
require("config.lsp")

-- On the "None" desktop: its theme (colors/none.lua). Elsewhere gruver16.
vim.cmd("colorscheme " .. ((vim.env.NONE_THEME or "") ~= "" and "none" or "gruver16"))
