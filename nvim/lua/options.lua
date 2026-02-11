local opt = vim.opt

-- opt.shell = "cmd.exe"
-- vim.opt.shellcmdflag = "/s /c"
-- vim.opt.shellquote = ""       -- Don't quote the whole command
-- vim.opt.shellxquote = ""      -- ...really, don't quote it.
-- vim.opt.shellpipe = ">"
vim.opt.grepformat = "%f:%l:%c:%m"

opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.cursorline = false
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
opt.completeopt = { "menu", "menuone", "noinsert" }
opt.path:append("**")
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.inccommand = "split"

local set = vim.opt_local

-- Set local settings for terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", {}),
  callback = function()
    set.number = false
    set.relativenumber = false
    set.scrolloff = 0

    vim.bo.filetype = "terminal"
  end,
})

-- Easily hit escape in terminal mode.
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>")

-- Open a terminal at the bottom of the screen with a fixed height.
vim.keymap.set("n", ",st", function()
  vim.cmd.new()
  vim.cmd.wincmd "J"
  vim.api.nvim_win_set_height(0, 12)
  vim.wo.winfixheight = true
  vim.cmd.term()
end)
