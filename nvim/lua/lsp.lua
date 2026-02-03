-- lua/lsp.lua

-- 1. Setup Mason (Installs the servers)
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "jdtls" }, 
})

-- 2. Configure JDTLS (The 0.11+ Way)
-- We use vim.lsp.config() to set the keymaps before enabling it.
vim.lsp.config("jdtls", {
    on_attach = function(client, bufnr)
        local opts = { noremap=true, silent=true, buffer=bufnr }
        
        -- Keymaps (IntelliJ-like)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, opts)
    end
})

-- 3. Enable the Server
-- This command replaces the old 'lspconfig.jdtls.setup' call.
vim.lsp.enable("jdtls")
