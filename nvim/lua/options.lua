local opt = vim.opt

-- opt.foldmethod = 'indent'
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = false
opt.smartindent = true
opt.autoindent = true
opt.cursorline = true
opt.number = true
opt.relativenumber = true
-- opt.numberwidth = 6
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
  local modified = vim.bo.modified and '' or ''
  return modified  .. filename
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
vim.g.nord_italic = false
vim.g.nord_bold = false
vim.opt.exrc = true
vim.opt.secure = true
-- vim.opt.shell = 'pwsh -NoLogo'
vim.opt.shell = 'cmd.exe /k cls'
vim.opt.timeoutlen = 300
vim.loader.enable()

vim.cmd("compiler gcc")
vim.opt.errorformat:append("%+G%.%#")

vim.keymap.set("n", "<leader>b", function()
  vim.cmd("silent !.\\build.bat *> build.log")
  vim.cmd("cfile build.log")
  vim.cmd("vert copen " .. math.floor(vim.o.columns / 2))
end, { desc = "Build" })

