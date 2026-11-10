-- nvim-treesitter's main branch reads only install_dir from its setup, so parsers
-- have to be requested through install(). Highlighting is started by the autocmd below.
local install_dir = vim.fn.stdpath("data") .. "/site/parser"

return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		-- other plugin files can add to this list with their own opts.ensure_installed
		opts_extend = { "ensure_installed" },
		opts = {
			ensure_installed = { "razor", "html", "css", "c", "cpp", "c_sharp", "lua", "vim", "vimdoc", "query", "java", "typescript", "tsx", "jsdoc" },
		},
		config = function(_, opts)
			local ts = require("nvim-treesitter")
			ts.setup({ install_dir = install_dir })

			-- same as Zed, which parses JavaScript with the tsx grammar
			vim.treesitter.language.register("tsx", { "javascript", "javascriptreact" })

			-- Zed's own queries, so tokens get the same colors as there. These are set
			-- explicitly because a file in queries/ on rtp would still get nvim-treesitter's
			-- queries merged in: Neovim follows "; inherits" in every file it finds.
			local zed_queries = vim.fs.joinpath(vim.fn.stdpath("config"), "zed-queries")
			for file in vim.fs.dir(zed_queries) do
				local lang = file:match("^(.+)%.scm$")
				if lang then
					local lines = vim.fn.readfile(vim.fs.joinpath(zed_queries, file))
					vim.treesitter.query.set(lang, "highlights", table.concat(lines, "\n"))
				end
			end

			local installed = ts.get_installed("parsers")
			local missing = vim.tbl_filter(function(lang)
				return not vim.list_contains(installed, lang)
			end, opts.ensure_installed)

			if #missing > 0 then
				if vim.fn.executable("tree-sitter") == 1 then
					ts.install(missing)
				else
					vim.notify(
						"tree-sitter CLI not found, cannot install parsers: " .. table.concat(missing, ", "),
						vim.log.levels.WARN
					)
				end
			end

			-- without this colors dont load properly
			vim.api.nvim_create_autocmd("FileType", {
				callback = function()
					if vim.bo.buftype == "" then
						pcall(vim.treesitter.start)
					end
				end,
			})

			-- Neovim's own indenting doesn't understand JSX tags, which breaks `=` and new lines
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
				callback = function(args)
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end
	},
}
