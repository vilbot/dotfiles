local M = {}

-- Toggles the shared terminal: hides it if visible, otherwise opens it.
-- split_cmd is the ex command that makes the window, nil reuses the current window.
function M.toggle(split_cmd)
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

return M
