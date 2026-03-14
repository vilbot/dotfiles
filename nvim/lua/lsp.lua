require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "jdtls", "clangd", "lua_ls", "csharp_ls"},
})


vim.lsp.config['*'] = {
    capabilities = require('blink.cmp').get_lsp_capabilities()
}

vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            runtime = { version = 'LuaJIT' },
            workspace = {
                checkThirdParty = false,
                library = vim.api.nvim_get_runtime_file('', true),
            },
            diagnostics = {
                globals = { 'vim' },
                disable = { 'redundant-parameter', 'trailing-space' }
            }
        },
    },
})

vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.cs",
    callback = function()
        vim.lsp.buf.format()
    end
})

vim.lsp.enable({"jdtls", "clangd", "lua_ls", "csharp_ls"})

