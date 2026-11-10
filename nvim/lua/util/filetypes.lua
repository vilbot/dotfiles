-- Applies the settings in config/filetypes.lua. Indent settings go through vim-sleuth,
-- whose defaults only apply when a file has no indent of its own to detect.
local M = {}

M.path = vim.fn.stdpath("config") .. "/lua/config/filetypes.lua"

local option_types = {
	tab_size = "number",
	hard_tabs = "boolean",
	detect_indent = "boolean",
	soft_wrap = "boolean",
	line_numbers = "boolean",
	relative_line_numbers = "boolean",
	spell = "boolean",
	text_width = "number",
	ruler = "number",
}

local window_options = {
	soft_wrap = "wrap",
	line_numbers = "number",
	relative_line_numbers = "relativenumber",
	spell = "spell",
	ruler = "colorcolumn",
}

local settings = {}

local function warn(message)
	vim.notify("Filetype settings: " .. message, vim.log.levels.WARN)
end

-- Sets window options for the file type. Only touches options set in the settings file,
-- and puts back the normal value when a window moves on to a file type without them.
local function apply_to_window(buf, win)
	local current = settings[vim.bo[buf].filetype] or {}
	local previous = vim.w[win].filetype_settings or {}
	local applied = {}
	for key, option in pairs(window_options) do
		local value = current[key]
		if value ~= nil then
			if key == "ruler" then
				value = tostring(value)
			end
			applied[key] = true
		elseif previous[key] then
			value = vim.go[option]
		end
		if value ~= nil then
			vim.api.nvim_set_option_value(option, value, { scope = "local", win = win })
		end
	end
	vim.w[win].filetype_settings = applied
end

local function apply_to_buffer(buf)
	if vim.bo[buf].buftype ~= "" then
		return
	end
	local current = settings[vim.bo[buf].filetype]
	if current and current.text_width then
		vim.bo[buf].textwidth = current.text_width
	end
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		apply_to_window(buf, win)
	end
end

-- Replaces the active settings, and tells sleuth about the indent ones
function M.set(new_settings)
	for ft in pairs(settings) do
		vim.g["sleuth_" .. ft .. "_defaults"] = nil
		vim.g["sleuth_" .. ft .. "_heuristics"] = nil
	end

	settings = {}
	for ft, entry in pairs(new_settings) do
		settings[ft] = {}
		for key, value in pairs(entry) do
			if not option_types[key] then
				warn(("unknown option %q for %s"):format(key, ft))
			elseif type(value) ~= option_types[key] then
				warn(("%s for %s should be a %s"):format(key, ft, option_types[key]))
			else
				settings[ft][key] = value
			end
		end

		local s = settings[ft]
		if s.tab_size or s.hard_tabs ~= nil then
			local hard_tabs = s.hard_tabs
			if hard_tabs == nil then
				hard_tabs = not vim.go.expandtab
			end
			vim.g["sleuth_" .. ft .. "_defaults"] = hard_tabs
				and "tabstop=" .. (s.tab_size or vim.go.tabstop)
				or "shiftwidth=" .. (s.tab_size or vim.go.shiftwidth)
		end
		if s.detect_indent == false then
			vim.g["sleuth_" .. ft .. "_heuristics"] = 0
		end
	end
end

-- Returns false and keeps the current settings if the file has a mistake in it
local function load_settings()
	local chunk, err = loadfile(M.path)
	if not chunk then
		warn(err)
		return false
	end
	local ok, result = pcall(chunk)
	if not ok or type(result) ~= "table" then
		warn(ok and "the file must return a table" or result)
		return false
	end
	M.set(result)
	return true
end

local function reapply_to_open_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd("silent! Sleuth")
			end)
			apply_to_buffer(buf)
		end
	end
end

local function is_settings_file(name)
	return vim.fn.resolve(name) == vim.fn.resolve(M.path)
end

local function open_settings()
	local ft = vim.bo.buftype == "" and vim.bo.filetype or ""
	local from_settings = is_settings_file(vim.api.nvim_buf_get_name(0))
	vim.cmd("edit " .. vim.fn.fnameescape(M.path))
	if ft == "" or from_settings then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local closing
	for i, line in ipairs(lines) do
		if line:match("^%s*" .. vim.pesc(ft) .. "%s*=") then
			vim.api.nvim_win_set_cursor(0, { i, 0 })
			return
		end
		if line:match("^}") then
			closing = i
		end
	end
	if closing then
		vim.api.nvim_buf_set_lines(0, closing - 1, closing - 1, false, { "\t" .. ft .. " = {  }," })
		vim.api.nvim_win_set_cursor(0, { closing, #ft + 6 })
	end
end

function M.setup()
	load_settings()

	local group = vim.api.nvim_create_augroup("FiletypeSettings", {})
	vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
		group = group,
		desc = "applies config/filetypes.lua",
		callback = function(args)
			apply_to_buffer(args.buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.lua",
		desc = "reloads config/filetypes.lua when it's saved",
		callback = function(args)
			if is_settings_file(args.match) and load_settings() then
				reapply_to_open_buffers()
			end
		end,
	})
	vim.api.nvim_create_user_command("FiletypeSettings", open_settings, {
		desc = "Open the settings for the current file type",
	})
end

return M
