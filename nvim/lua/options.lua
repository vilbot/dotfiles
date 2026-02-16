local opt = vim.opt

opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.cursorline = true
opt.number = true
opt.relativenumber = true
opt.numberwidth = 4
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
opt.signcolumn = "no"
opt.splitright = true
opt.splitbelow = false
opt.wildmenu = true
opt.title = true
opt.titlestring = "%{%v:lua.MyTitleString()%}"
function _G.MyTitleString()
  local filename = vim.fn.expand('%:t') ~= '' and vim.fn.expand('%:t') or vim.fn.expand('%:F')
  local modified = vim.bo.modified and '' or ''
  return modified  .. filename
end
opt.laststatus = 3
opt.completeopt = { "menu", "menuone", "noinsert" }
opt.path:append("**")
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.inccommand = "split"
opt.grepformat = "%f:%l:%c:%m"
opt.swapfile = false
