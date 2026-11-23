-- Editor autocmds. Autocmds that belong to one plugin live in that plugin's spec.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	desc = "removes autoinsertion of comments",
	callback = function()
		vim.opt_local.formatoptions:remove({ "c", "r", "o" })
	end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "highlights yanking",
	callback = function()
		vim.hl.on_yank({
			higroup = 'YankHighlight',
			timeout = 150
		})
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[buf].buftype == 'terminal' then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end
})

vim.api.nvim_create_autocmd("User", {
	pattern = "NoneTheme",
	nested = true, -- so ColorScheme fires (plugins/ui.lua sets its indent colors there)
	desc = "the None desktop's theme changed: draw with the new palette (palettes/current.lua)",
	callback = function()
		-- only the gruver16 family (colors/<name>.lua with a palette) draws with None's theme
		local name = vim.g.colors_name
		if name and pcall(require, "palettes." .. name) then
			vim.cmd.colorscheme(name)
		end
	end,
})

require("util.build").setup()
require("util.filetypes").setup()
