local map = vim.keymap.set

-- Move text
map("v", "<A-j>", ":m '>+1<CR>gv=gv")
map("v", "<A-k>", ":m '<-2<CR>gv=gv")

map('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace on cursor"})
map('x', '<leader>S', [[:s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace in selection"})

map('n', 'x', '"_x')
map('n', '<leader>p', '"0p')
map('n', '<leader>P', '"0P')
map('n', '<C-_>', 'gcc', { remap = true })
map('v', '<C-_>', 'gc', { remap = true })
map('n', 'J', 'mzJ`z', { desc = 'Join lines without moving cursor' })

map('n', '<leader>m', ':make<CR>')
map('n', '<leader>cn', ':cn<CR>', {desc = "next error"})
map('n', '<leader>cp', ':cp<CR>', {desc = "previous error"})
map('n', '<leader>co', ':copen<CR>', {desc = "open quickfix"})

local functions = require('functions')
map('t', '<esc>', '<C-\\><C-n>')
map('n', '<leader>t', function() functions.open_term(nil) end)
map('n', '<leader>j', function() functions.open_term('split') end)
map('n', '<leader>k', function() functions.open_term('vsplit') end)
-- map('n', '<leader>t', '<CMD>term<CR>')
-- map('n', '<leader>j', '<CMD>split | term<CR>')
-- map('n', '<leader>k', '<CMD>vsplit | term<CR>')

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
        map('n', '<leader>rf',  vim.lsp.buf.references, opts)
        map('n', '<leader>d',  vim.diagnostic.open_float, opts)
        map('n', ']d',         function() vim.diagnostic.jump({count=1, float=true}) end, opts)
        map('n', '[d',         function() vim.diagnostic.jump({count=-1, float=true}) end, opts)
    end,
})

local builtin = require('telescope.builtin')
local action = require 'telescope.actions'
map('n', '<C-f>', function ()
    builtin.find_files({
        previewer = false,
        create_layout = function(picker)
            local Layout = require "telescope.pickers.layout"
            local win = vim.api.nvim_get_current_win()
            local w = vim.api.nvim_win_get_width(win)
            local pos = vim.api.nvim_win_get_position(win)
            local results_h = 10
            local prompt_h = 1

            local function create_window(enter, width, height, row, col)
                local bufnr = vim.api.nvim_create_buf(false, true)
                local winid = vim.api.nvim_open_win(bufnr, enter, {
                    style = "minimal",
                    relative = "editor",
                    width = width,
                    height = height,
                    row = row,
                    col = col,
                    border = "none",
                })
                vim.wo[winid].winhighlight = "Normal:TelescopeNormal,FloatBorder:TelescopeNormal"
                return Layout.Window { bufnr = bufnr, winid = winid }
            end

            local function destroy_window(window)
                if window then
                    if vim.api.nvim_win_is_valid(window.winid) then
                        vim.api.nvim_win_close(window.winid, true)
                    end
                    if vim.api.nvim_buf_is_valid(window.bufnr) then
                        vim.api.nvim_buf_delete(window.bufnr, { force = true })
                    end
                end
            end

            return Layout {
                picker = picker,
                mount = function(self)
                    self.prompt = create_window(true, w, prompt_h, pos[1], pos[2])
                    self.results = create_window(false, w, results_h, pos[1] + prompt_h, pos[2])
                    self.preview = nil

                    vim.api.nvim_create_autocmd("TextChangedI", {
                        buffer = self.prompt.bufnr,
                        callback = function()
                            vim.defer_fn(function()
                                if not vim.api.nvim_win_is_valid(self.results.winid) then return end
                                local line_count = vim.api.nvim_buf_line_count(self.results.bufnr)
                                local new_h = math.max(1, math.min(line_count, results_h))
                                vim.api.nvim_win_set_height(self.results.winid, new_h)
                            end, 50)
                        end,
                    })
                end,
                unmount = function(self)
                    destroy_window(self.prompt)
                    destroy_window(self.results)
                end,
                update = function(self) end,
            }
        end,
    })
end)
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
map('n', '<C-g>', builtin.live_grep)
map('v', '<C-g>', builtin.grep_string)
map('n', '<leader>p', builtin.registers)
map('n', '<C-m>', builtin.marks)

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
