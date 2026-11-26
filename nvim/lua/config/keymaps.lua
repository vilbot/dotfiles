-- Editor keymaps. Keymaps that belong to one plugin live in that plugin's spec under
-- `keys`, LSP keymaps live in config/lsp.lua.
local platform = require("config.platform")
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
map('n', '<C-`>', '<cmd>exe v:count1 . "ToggleTerm"<cr>', { desc = "Toggle terminal" })
map('t', '<C-`>', '<cmd>ToggleTerm<cr>', { desc = "Toggle terminal" })
map('n', '<leader>ts', '<cmd>TermSelect<cr>', { desc = "Select terminal" })
map('n', '<leader>ta', '<cmd>ToggleTermToggleAll<cr>', { desc = "Toggle all terminals" })
map('n', '<leader>tf', '<cmd>ToggleTerm direction=float<cr>', { desc = "Floating terminal" })

map('n', '<leader>oo', '<cmd>OverseerToggle<cr>', { desc = "Overseer: toggle task list" })
map('n', '<leader>or', '<cmd>OverseerRun<cr>', { desc = "Overseer: run task" })
map('n', '<leader>os', '<cmd>OverseerShell<cr>', { desc = "Overseer: run shell command" })
map('n', '<leader>oa', '<cmd>OverseerTaskAction<cr>', { desc = "Overseer: task action" })

if platform.is_mac then
	map('n', '<D-/>', 'gcc', { remap = true })
	map('v', '<D-/>', 'gc', { remap = true })
else
	-- Windows and Linux have no usable cmd key.
	map('n', '<C-/>', 'gcc', { remap = true })
	map('v', '<C-/>', 'gc', { remap = true })
end

map('n', '<A-->',  '<C-w>_')
map('n', '<A-=>',  '<C-w>=')
map('n', '<A-\\>', '<C-w>|')

local has_agent, agent = pcall(require, "none.agent")
if has_agent then
	map("x", "<C-S-.>",    agent.send_selection,   { desc = "Agent: send selection ref" })
	map("x", "<C->>",      agent.send_selection,   { desc = "Agent: send selection ref" })
	map("x", "<leader>as", agent.send_selection,   { desc = "Agent: send selection ref" })
	map("n", "<C-S-.>",    agent.send_file,        { desc = "Agent: send file ref" })
	map("n", "<C->>",      agent.send_file,        { desc = "Agent: send file ref" })
	map("n", "<leader>af", agent.send_file,        { desc = "Agent: send file ref" })
	map("n", "<leader>ad", agent.send_diagnostic,  { desc = "Agent: send line diagnostic" })
	map("n", "<leader>aD", agent.send_diagnostics, { desc = "Agent: send buffer diagnostics" })
	map("n", "<leader>ar", agent.diff,             { desc = "Agent: preview hunk / diff" })
end

