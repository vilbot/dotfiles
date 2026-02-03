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
