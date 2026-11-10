-- Finds the nearest build script. It drives both :make (through 'makeprg') and <leader>b.
local platform = require("config.platform")

local M = {}

local build_scripts = platform.is_win
	and { 'build.bat', 'build.cmd', 'build.sh' }
	or { 'build.sh', 'build.bat' }

-- looks upward from the file in buf for a build script
local function find_script(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	local start = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
	return vim.fs.find(build_scripts, { path = start, upward = true, type = 'file' })[1]
end

-- cmd.exe can't run a shell script, and a non-executable one needs an interpreter
local function needs_sh(script)
	return script:sub(-3) == '.sh' and (platform.is_win or vim.fn.executable(script) == 0)
end

function M.set_makeprg(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= '' then return end

	local found = find_script(buf)
	if not found then return end

	local prg
	if needs_sh(found) then
		prg = platform.is_win and (found:gsub('\\', '/')) or found
		-- escape first, so only spaces inside the path get escaped, not the separator
		prg = 'sh ' .. vim.fn.escape(prg, ' |')
	else
		prg = vim.fn.escape(found, ' |')
	end

	vim.bo[buf].makeprg = prg
end

-- Runs the script from the current directory, like :make does, and loads its output
-- into a quickfix window taking half the screen. The output is also kept in build.log.
function M.run()
	local script = find_script(vim.api.nvim_get_current_buf())
	if not script then
		vim.notify('no ' .. table.concat(build_scripts, ' or ') .. ' found above this file', vim.log.levels.ERROR)
		return
	end

	local cmd
	if needs_sh(script) then
		cmd = { 'sh', platform.is_win and (script:gsub('\\', '/')) or script }
	elseif platform.is_win then
		cmd = { 'cmd.exe', '/c', script }
	else
		cmd = { script }
	end

	-- both streams share one handler so errors stay next to the output around them
	local output = {}
	local function collect(_, data)
		if data then output[#output + 1] = data end
	end
	vim.system(cmd, { text = true, stdout = collect, stderr = collect }):wait()

	vim.fn.writefile(vim.split(table.concat(output), '\n', { trimempty = true }), 'build.log')
	vim.cmd('cfile build.log')
	vim.cmd('vert copen ' .. math.floor(vim.o.columns / 2))
end

function M.setup()
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
end

return M
