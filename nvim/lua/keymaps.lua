local map = vim.keymap.set

vim.g.VM_leader = '\\'

-- VISUAL-MULTI
vim.g.VM_maps = {
    ["Find Under"]      = "gn",
    ["Find Next"]       = "gn",
    ["Find Prev"]       = "g<S-n>",
    ["Skip Region"]     = "gm",
    ["Remove Region"]   = "g<S-m>",
    ["Select All"]      = "ga",
    ["Add Cursor Up"]   = "<C-A-k>",
    ["Add Cursor Down"] = "<C-A-j>",
}

-- Move text
map("v", "<A-j>", ":m '>+1<CR>gv=gv")
map("v", "<A-k>", ":m '<-2<CR>gv=gv")

map('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace on cursor"})
map("x", "<leader>S", [[:s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace in selection"})
map('n', 'x', '"_x')
map('n', '0p', '"0p')
map('n', '0P', '"0P')

-- TELESCOPE
local builtin = require('telescope.builtin')
local action = require 'telescope.actions'
map('n', '<leader>w', '<CMD>Oil<CR>')
map('n', '<C-f>', builtin.find_files)
map('n', '<C-g>', builtin.live_grep)
map('v', '<C-g>', builtin.grep_string)
map('n', '<C-p>', builtin.registers)
map('n', '<C-b>', function()
    require('telescope.builtin').buffers({
        attach_mappings = function(prompt_bufnr, map_local)
            map_local('i', '<C-d>', function()
                action.delete_buffer(prompt_bufnr)
            end)
            map_local('n', '<C-d>', function()
                action.delete_buffer(prompt_bufnr)
            end)
            return true
        end,
    })
end, {desc = "Buffers with delete capability"})

-- SMART-SPLITS
local splits = require('smart-splits')
map('n', '<A-h>',  splits.resize_left)
map('n', '<A-j>',  splits.resize_down)
map('n', '<A-k>',  splits.resize_up)
map('n', '<A-l>',  splits.resize_right)
map('n', '<A-->',  '<C-w>_')
map('n', '<A-=>',  '<C-w>=')
map('n', '<A-\\>', '<C-w>|')

