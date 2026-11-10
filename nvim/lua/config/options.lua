local platform = require("config.platform")
local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- opt.foldmethod = 'indent'
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.cursorline = true
opt.number = true
opt.relativenumber = true
opt.numberwidth = 5
-- vim.o.statuscolumn = "%l%s"
opt.ruler = true
opt.wrap = false
opt.sidescroll = 5
opt.scrolloff = 8
opt.incsearch = true
opt.hlsearch = true
opt.updatetime = 50
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.showmode = true
opt.signcolumn = "yes"
opt.splitright = true
opt.splitbelow = false
opt.wildmenu = true
opt.winborder = "rounded"
opt.title = true
opt.titlestring = "%{%v:lua.MyTitleString()%}"
function _G.MyTitleString()
	local filename = vim.fn.expand('%:t') ~= '' and vim.fn.expand('%:t') or vim.fn.expand('%:F')
	local modified = vim.bo.modified and '• ' or ''
	return modified .. filename
end
opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:block"
opt.laststatus = 3
opt.completeopt = { "menu", "menuone", "noinsert" }
opt.path:append("**")
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.inccommand = "split"
opt.grepformat = "%f:%l:%c:%m"
opt.swapfile = false
opt.exrc = true
opt.secure = true
-- vim.opt.shell = 'pwsh -NoLogo'
opt.timeoutlen = 300

vim.cmd("compiler! gcc")
opt.errorformat:append("%+G%.%#")

vim.filetype.add({
	extension = { razor = "razor" },
})

if platform.is_win then
	opt.shell = "cmd.exe"
	opt.shellcmdflag = "/s /c"
	opt.shellredir = ">%s 2>&1"
	opt.shellpipe = ">%s 2>&1"
	opt.shellquote = ""
	opt.shellxquote = '"'
end
