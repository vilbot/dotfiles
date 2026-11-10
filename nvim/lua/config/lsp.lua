-- Behaviour shared by every language server. The server list is in lua/plugins/lsp.lua,
-- per-server settings are in after/lsp/<server>.lua.
vim.lsp.config['*'] = {
	capabilities = require('blink.cmp').get_lsp_capabilities()
}

-- They paint over treesitter. Zed has them off too, so colors come only from zed-queries/.
vim.lsp.semantic_tokens.enable(false)

-- :h vim.lsp.buf.hover.Opts
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local map = vim.keymap.set
		local opts = { buffer = args.buf }
		map('n', 'gd',         vim.lsp.buf.definition, opts)
		map('n', 'gD',         vim.lsp.buf.declaration, opts)
		map('n', 'gr',         vim.lsp.buf.references, opts)
		map('n', 'gi',         vim.lsp.buf.implementation, opts)
		map('n', 'K',          vim.lsp.buf.hover, opts)
		map('n', 'grn',        vim.lsp.buf.rename, opts)
		map('n', '<leader>ca', vim.lsp.buf.code_action, opts)
		map('n', '<leader>f',  vim.lsp.buf.format, opts)
		map('n', '<leader>rf', vim.lsp.buf.references, opts)
		map('n', '<leader>d',  vim.diagnostic.open_float, opts)
		map('n', ']d',         function() vim.diagnostic.jump({count=1, float=true}) end, opts)
		map('n', '[d',         function() vim.diagnostic.jump({count=-1, float=true}) end, opts)
	end,
})

-- Add a glob here to format that file type on save.
local format_on_save = { "*.cs" }

vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = format_on_save,
	callback = function()
		vim.lsp.buf.format()
	end
})
