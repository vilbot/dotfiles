local map = vim.keymap.set

-- Move text
map("v", "<A-j>", ":m '>+1<CR>gv=gv")
map("v", "<A-k>", ":m '<-2<CR>gv=gv")

map('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace on cursor"})
map('x', '<leader>S', [[:s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace in selection"})

map('n', 'x', '"_x')
map('n', '0p', '"0p')
map('n', '0P', '"0P')
map('n', '<C-_>', 'gcc', { remap = true })
map('v', '<C-_>', 'gc', { remap = true })
map('n', 'J', 'mzJ`z', { desc = 'Join lines without moving cursor' })


map('n', '<leader>q', '<cmd>NvimTreeOpen<cr>')
map('n', '<leader>w', '<CMD>Oil<CR>')

-- :h vim.lsp.buf.hover.Opts
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local opts = { buffer = args.buf }
        map('n', 'gd',         vim.lsp.buf.definition, opts)
        map('n', 'gD',         vim.lsp.buf.declaration, opts)
        map('n', 'gr',         vim.lsp.buf.references, opts)
        map('n', 'gi',         vim.lsp.buf.implementation, opts)
        map('n', 'K',          vim.lsp.buf.hover, opts)
        map('n', '<leader>rn', vim.lsp.buf.rename, opts)
        map('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        map('n', '<leader>f',  vim.lsp.buf.format, opts)
        map('n', '<leader>t',  vim.lsp.buf.references, opts)
        map('n', '<leader>d',  vim.diagnostic.open_float, opts)
        map('n', ']d',         function() vim.diagnostic.jump({count=1, float=true}) end, opts)
        map('n', '[d',         function() vim.diagnostic.jump({count=-1, float=true}) end, opts)
    end,
})

local builtin = require('telescope.builtin')
local action = require 'telescope.actions'
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

-- Navigate to the next page in the PDF (supports counts, e.g., 5<leader>jj)
map("n", "<leader>jj", function()
    local count = vim.v.count1
    for _ = 1, count do
        require('pdfview.renderer').next_page()
    end
end, { desc = "PDFview: Next page(s)" })

-- Navigate to the previous page in the PDF (supports counts, e.g., 5<leader>kk)
map("n", "<leader>kk", function()
    local count = vim.v.count1
    for _ = 1, count do
        require('pdfview.renderer').previous_page()
    end
end, { desc = "PDFview: Previous page(s)" })

-- Navigate to the next page in the PDF
-- map("n", "<leader>jj", "<cmd>:lua require('pdfview.renderer').next_page()<CR>", { desc = "PDFview: Next page" })

-- Navigate to the previous page in the PDF
-- map("n", "<leader>kk", "<cmd>:lua require('pdfview.renderer').previous_page()<CR>", { desc = "PDFview: Previous page" })



local splits = require('smart-splits')
map('n', '<A-h>',  splits.resize_left)
map('n', '<A-j>',  splits.resize_down)
map('n', '<A-k>',  splits.resize_up)
map('n', '<A-l>',  splits.resize_right)
map('n', '<A-->',  '<C-w>_')
map('n', '<A-=>',  '<C-w>=')
map('n', '<A-\\>', '<C-w>|')

