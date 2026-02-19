require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "jdtls", "clangd", "lua_ls"},
})

local keymaps = function() 
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, opts)
end

vim.lsp.config('*', {
    dependencies = { 'saghen/blink.cmp' },
    capabilities = require('blink.cmp').get_lsp_capabilities(),
})

vim.lsp.config('jdtls', {

    on_attach = function(client, bufnr)
        local opts = { noremap=true, silent=true, buffer=bufnr }
        keymaps()
    end
})

vim.lsp.config('clangd', {

    on_attach = function(client, bufnr)
        local opts = { noremap=true, silent=true, buffer=bufnr }
        keymaps();
    end
})

vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            runtime = {
                version = 'LuaJIT',
            },
            diagnostics = {
                globals = { 'vim' },
            },
            workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
            },
            telemetry = {
                enable = false,
            },
        },
    },
    on_attach = function(client, bufnr)
        local opts = { noremap=true, silent=true, buffer=bufnr }
        keymaps()
    end
})

vim.diagnostic.config({
  float = { border = "rounded" }
})

local open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = "rounded"
  return open_floating_preview(contents, syntax, opts, ...)
end

vim.lsp.enable("jdtls")
vim.lsp.enable("clangd")
vim.lsp.enable("lua_ls")

