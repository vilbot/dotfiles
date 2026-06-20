vim.filetype.add({
    extension = { razor = "razor" }
})

require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "jdtls", "clangd", "lua_ls"},
})

vim.lsp.config['*'] = {
    capabilities = require('blink.cmp').get_lsp_capabilities()
}

require("mason-registry")
local rzls_path = vim.fn.expand("$MASON/packages/roslyn/libexec/.razorExtension")
local cmd = {
    "roslyn",
    "--stdio",
    "--logLevel=Information",
    "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
    "--razorSourceGenerator=" .. vim.fs.joinpath(rzls_path, "Microsoft.CodeAnalysis.Razor.Compiler.dll"),
    "--razorDesignTimePath=" .. vim.fs.joinpath(rzls_path, "Targets", "Microsoft.NET.Sdk.Razor.DesignTime.targets"),
    "--extension",
    vim.fs.joinpath(rzls_path, "Microsoft.VisualStudioCode.RazorExtension.dll"),
}

vim.lsp.config('roslyn', {
    cmd = cmd,
    handlers = require("roslyn.razor.handlers"),
    filetypes = { "cs", "razor"},
    root_markers = { { ".sln", ".csproj", "project.json" }, ".git" },
})

vim.lsp.config('jdtls', {
    cmd = {
        'C:\\Program Files\\Java\\jdk-21.0.10\\bin\\java.exe',
        '-jar',
        vim.fn.glob(vim.fn.stdpath('data') .. '/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar'),
        '-configuration',
        vim.fn.stdpath('data') .. '/mason/packages/jdtls/config_win',
        '-data',
        vim.fn.stdpath('data') .. '/jdtls-workspace',
    }
})

vim.lsp.config('clangd', {
    filetypes = { 'cpp' },
    cmd = {
        "clangd", 
        "--header-insertion=never",
    },
    handlers = {
        ["textDocument/publishDiagnostics"] = function() end,
    }
})

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

vim.lsp.enable({ "html", "cssls", "jdtls", "clangd", "lua_ls"})

