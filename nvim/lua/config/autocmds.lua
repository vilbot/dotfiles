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

require("util.build").setup()
require("util.filetypes").setup()
