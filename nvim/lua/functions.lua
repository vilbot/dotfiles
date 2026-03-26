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
            higroup = 'WildMenu',
            timeout = 150
        })
    end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*.pdf",
  callback = function()
    local file_path = vim.api.nvim_buf_get_name(0)
    require("pdfview").open(file_path)
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "gruber-darker",
    callback = function()
        -- local highlight_color = '#abbce5' 
        local highlight_color = '#ffffff' 
        vim.api.nvim_set_hl(0, 'GruberDarkerDarkNiagara', { fg = highlight_color })
        vim.api.nvim_set_hl(0, 'MatchParen', { link = 'Visual' })
        vim.api.nvim_set_hl(0, 'NormalFloat', {fg = '#dadada', bg = '#181818'})
        vim.api.nvim_set_hl(0, 'FloatBorder', {fg = '#dadada', bg = '#181818'})
        vim.api.nvim_set_hl(0, 'BlinkCmpGhostText', {fg = '#787878', bg = '#282828'})
    end,
})

local open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = "rounded"
  return open_floating_preview(contents, syntax, opts, ...)
end

