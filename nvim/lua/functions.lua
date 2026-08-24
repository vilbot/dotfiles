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
        vim.hl.hl_op({
            higroup = 'IncSearch',
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

vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "nordic",
    callback = function()
        -- local highlight_color = '#abbce5' 
        vim.api.nvim_set_hl(0, 'Visual', { link = 'IncSearch' })
    end,
})

local open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = "rounded"
    return open_floating_preview(contents, syntax, opts, ...)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[buf].buftype == 'terminal' then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
    end
})

local M = {}
function M.open_term(split_cmd)
    -- find existing terminal buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == 'terminal' then
            -- check if it's already visible in a window
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == buf then
                    vim.api.nvim_set_current_win(win)
                    vim.autocmd('insertmode')
                    return
                end
            end
            -- not visible, open it in a split
            if split_cmd then vim.cmd(split_cmd) end
            vim.api.nvim_win_set_buf(0, buf)
            return
        end
    end
    -- no terminal exists, create one
    if split_cmd then vim.cmd(split_cmd) end
    vim.cmd('terminal')
end

return M
