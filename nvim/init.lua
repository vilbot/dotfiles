vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin;" .. vim.env.PATH

require("options")
require("lazy-setup")
require("functions")
require("keymaps")
require("lsp")
vim.cmd("colorscheme custom")

if vim.fn.has("win32") == 1 then
    vim.opt.shell = "cmd.exe"
    vim.opt.shellcmdflag = "/s /c"
    vim.opt.shellredir = ">%s 2>&1"
    vim.opt.shellpipe = ">%s 2>&1"
    vim.opt.shellquote = ""
    vim.opt.shellxquote = '"'
	vim.opt_local.errorformat = "%f:%l:%c: %trror: %m,%f:%l:%c: %tarning: %m,%f:%l:%c: %m,%%f:%l: %m,%C%m"
end

if vim.g.neovide then
	vim.o.guifont = "Liberation Mono:h11:#h-slight:#e-antialias"
	vim.g.neovide_pixel_geometry = "RGBH"
	vim.g.neovide_text_gamma = 0.8
	vim.g.neovide_text_contrast = 0.1
	vim.opt.linespace = 6
	-- vim.opt.linewidth = 6
	vim.g.neovide_cursor_animation_length = 0
	vim.g.neovide_cursor_trail_size = 0
	vim.g.neovide_cursor_vfx_mode = ""
	vim.g.neovide_cursor_animate_in_insert_mode = false
	vim.g.neovide_cursor_animate_command_line = false

	-- window and scroll animation
	vim.g.neovide_position_animation_length = 0
	vim.g.neovide_scroll_animation_length = 0

	-- floating window (popup menu, hover box) effects
	vim.g.neovide_floating_shadow = false
	vim.g.neovide_floating_blur_amount_x = 0
	vim.g.neovide_floating_blur_amount_y = 0

	-- transparency
	vim.g.neovide_opacity = 1.0
	vim.g.neovide_normal_opacity = 1.0

	-- padding (optional, removes the border space)
	vim.g.neovide_padding_top = 10
	vim.g.neovide_padding_bottom = 0
	vim.g.neovide_padding_right = 0
	vim.g.neovide_padding_left = 0

	vim.g.neovide_scale_factor = 1.0
	local function change_scale_factor(delta)
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
	end

	vim.keymap.set("n", "<C-=>", function() change_scale_factor(1.10) end)
	vim.keymap.set("n", "<C-->", function() change_scale_factor(0.90) end)
	vim.keymap.set("n", "<C-0>", function() vim.g.neovide_scale_factor = 1.0 end)
end
