vim.loader.enable()

require("config.options") -- leader and options: must run before plugins load
require("config.lazy")    -- plugin manager, imports every file in lua/plugins/
require("config.autocmds")
require("config.keymaps")
require("config.lsp")

vim.cmd("colorscheme custom")
