vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    desc = "removes autoinsertion of comments",
    callback = function()
        vim.opt_local.formatoptions:remove({ "c", "r", "o" })
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
        vim.api.nvim_set_hl(0, 'Visual', { bg = '#60728a', fg = '#242933' })
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

local M = {}
function M.open_term(split_cmd)
    -- find existing terminal buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == 'terminal' then
            -- check if it's already visible in a window
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == buf then
                    vim.api.nvim_set_current_win(win)
                    vim.cmd('hide')
                    return
                end
            end
            -- not visible, open it in a split
            if split_cmd then vim.cmd(split_cmd) end
            vim.api.nvim_win_set_buf(0, buf)
            vim.cmd('startinsert')
            return
        end
    end
    -- no terminal exists, create one
    if split_cmd then vim.cmd(split_cmd) end
    vim.cmd('terminal')
    vim.cmd('startinsert')
end

-- looks upward from the current file for a build script and sets it as makeprg
local is_win = vim.fn.has('win32') == 1
local build_scripts = is_win
    and { 'build.bat', 'build.cmd', 'build.sh' }
    or { 'build.sh', 'build.bat' }

function M.set_makeprg(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype ~= '' then return end

    local name = vim.api.nvim_buf_get_name(buf)
    local start = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()

    local found = vim.fs.find(build_scripts, { path = start, upward = true, type = 'file' })[1]
    if not found then return end

    -- escape first, so only spaces inside the path get escaped, not the separator
    local prg = vim.fn.escape(found, ' |')
    if found:sub(-3) == '.sh' then
        -- cmd.exe can't run a shell script, and a non-executable one needs an interpreter
        if is_win then
            prg = 'sh ' .. vim.fn.escape((found:gsub('\\', '/')), ' |')
        elseif vim.fn.executable(found) == 0 then
            prg = 'sh ' .. prg
        end
    end

    vim.bo[buf].makeprg = prg
end

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    pattern = '*',
    desc = 'set makeprg to the nearest build script',
    callback = function(args)
        M.set_makeprg(args.buf)
    end,
})

-- abort :make when no build script was detected, instead of silently falling back
-- to the global 'makeprg'. this has to be vimscript: a :throw (or error) raised in a
-- lua callback is caught at the callback boundary and :make runs anyway.
vim.cmd(string.format([[
    augroup BuildScriptMakeprg
        autocmd!
        autocmd QuickFixCmdPre make
            \ if &l:makeprg ==# '' |
            \   throw 'no %s found above this file' |
            \ endif
    augroup END
]], table.concat(build_scripts, ' or ')))


return M
