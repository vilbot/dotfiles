vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("options")
require("lazy-setup")
require("functions")
require("keymaps")
require("lsp")
vim.cmd("colorscheme gruver16")
