-- Editor keymaps. Keymaps that belong to one plugin live in that plugin's spec under
-- `keys`, LSP keymaps live in config/lsp.lua.
local platform = require("config.platform")
local terminal = require("util.terminal")
local map = vim.keymap.set

-- Move text
map("v", "<A-j>", ":m '>+1<CR>gv=gv")
map("v", "<A-k>", ":m '<-2<CR>gv=gv")

map('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace on cursor"})
map('x', '<leader>S', [[:s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {desc = "find and replace in selection"})

map('n', 'x', '"_x')
map('n', '<leader>P', '"0P')
-- Terminals disagree on what ctrl+/ sends, so map both forms.
map('n', '<C-_>', 'gcc', { remap = true })
map('v', '<C-_>', 'gc', { remap = true })
map('n', 'J', 'mzJ`z', { desc = 'Join lines without moving cursor' })

map('n', '<leader>cn', ':cn<CR>', {desc = "next error"})
map('n', '<leader>cp', ':cp<CR>', {desc = "previous error"})
map('n', '<leader>co', ':copen<CR>', {desc = "open quickfix"})

map("n", "<leader>b", function() require("util.build").run() end, { desc = "Build" })

map('t', '<esc>', '<C-\\><C-n>')
map('t', '<C-w>', '<C-\\><C-n><C-w>')
if platform.is_mac then
	map({'n', 't'}, '<D-j>', function() terminal.toggle('belowright 15split') end)
	map({'n', 't'}, '<D-k>', function() terminal.toggle('vsplit') end)
	map('n', '<D-/>', 'gcc', { remap = true })
	map('v', '<D-/>', 'gc', { remap = true })
else
	-- Windows and Linux have no usable cmd key.
	map({'n', 't'}, '<C-j>', function() terminal.toggle('belowright 15split') end)
	map({'n', 't'}, '<C-k>', function() terminal.toggle('vsplit') end)
	map('n', '<C-/>', 'gcc', { remap = true })
	map('v', '<C-/>', 'gc', { remap = true })
end

map('n', '<A-->',  '<C-w>_')
map('n', '<A-=>',  '<C-w>=')
map('n', '<A-\\>', '<C-w>|')
