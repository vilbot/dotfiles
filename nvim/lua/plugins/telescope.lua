return {
	{ "nvim-lua/plenary.nvim" },
	{
		"nvim-telescope/telescope.nvim",
		branch = 'master',
		-- branch = "0.1.x",
		dependencies = { "nvim-lua/plenary.nvim" },
		lazy = false,
		keys = {
			{ '<C-f>', function() require('telescope.builtin').find_files() end },
			-- map('n', '<C-f>', function ()
			--     builtin.find_files({
			--         previewer = false,
			--         create_layout = function(picker)
			--             local Layout = require "telescope.pickers.layout"
			--             local win = vim.api.nvim_get_current_win()
			--             local w = vim.api.nvim_win_get_width(win)
			--             local pos = vim.api.nvim_win_get_position(win)
			--             local results_h = 10
			--             local prompt_h = 1
			--
			--             local function create_window(enter, width, height, row, col)
			--                 local bufnr = vim.api.nvim_create_buf(false, true)
			--                 local winid = vim.api.nvim_open_win(bufnr, enter, {
			--                     style = "minimal",
			--                     relative = "editor",
			--                     width = width,
			--                     height = height,
			--                     row = row,
			--                     col = col,
			--                     border = "none",
			--                 })
			--                 vim.wo[winid].winhighlight = "Normal:TelescopeNormal,FloatBorder:TelescopeNormal"
			--                 return Layout.Window { bufnr = bufnr, winid = winid }
			--             end
			--
			--             local function destroy_window(window)
			--                 if window then
			--                     if vim.api.nvim_win_is_valid(window.winid) then
			--                         vim.api.nvim_win_close(window.winid, true)
			--                     end
			--                     if vim.api.nvim_buf_is_valid(window.bufnr) then
			--                         vim.api.nvim_buf_delete(window.bufnr, { force = true })
			--                     end
			--                 end
			--             end
			--
			--             return Layout {
			--                 picker = picker,
			--                 mount = function(self)
			--                     self.prompt = create_window(true, w, prompt_h, pos[1], pos[2])
			--                     self.results = create_window(false, w, results_h, pos[1] + prompt_h, pos[2])
			--                     self.preview = nil
			--
			--                     vim.api.nvim_create_autocmd("TextChangedI", {
			--                         buffer = self.prompt.bufnr,
			--                         callback = function()
			--                             vim.defer_fn(function()
			--                                 if not vim.api.nvim_win_is_valid(self.results.winid) then return end
			--                                 local line_count = vim.api.nvim_buf_line_count(self.results.bufnr)
			--                                 local new_h = math.max(1, math.min(line_count, results_h))
			--                                 vim.api.nvim_win_set_height(self.results.winid, new_h)
			--                             end, 50)
			--                         end,
			--                     })
			--                 end,
			--                 unmount = function(self)
			--                     destroy_window(self.prompt)
			--                     destroy_window(self.results)
			--                 end,
			--                 update = function(self) end,
			--             }
			--         end,
			--     })
			-- end)
			{
				'<C-b>',
				function()
					local action = require('telescope.actions')
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
				end,
				desc = "Buffers with delete capability",
			},
			{ '<C-g>', function() require('telescope.builtin').live_grep() end },
			{ '<C-g>', function() require('telescope.builtin').grep_string() end, mode = 'v' },
			{ '<leader>p', function() require('telescope.builtin').registers() end },
			-- map('n', '<C-m>', builtin.marks)
		},
		opts = {
			defaults = {
				layout_strategy = "horizontal",
				layout_config = {
					prompt_position = "top"
				},
				sorting_strategy = "ascending",
				selection_caret = "☞ ", -- ➤
				winblend = 0,
				mappings = {
					i = {
						["<C-s>"] = "select_horizontal",
					},
					n = {
						["<C-s>"] = "select_horizontal",
					}
				},
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case"
				},
				file_ignore_patterns = {
					"target/",
					"%.class",
					"%.jar",
					"%.idea/",
					"%.git/"
				}
			},
			pickers = {
				find_files = {
					enable_preview = true,
					previewer = false,
					theme = "ivy",
					layout_config = {
						height = 0.25
					}
				},
				live_grep = {
					layout_strategy = "flex",
				},
				grep_string = {
					layout_strategy = "flex",
				},
				registers = {
					theme = "cursor",
				},
				marks = {
					layout_strategy = "flex",
				},
				buffers = {
					enable_preview = true,
					previewer = false,
					theme = "ivy",
					layout_config = {
						height = 0.25
					}
				},
				colorscheme = {
					enable_preview = true,
					previewer = false,
					theme = "ivy",
					layout_config = {
						height = 0.25
					}
				}
			}
		},
	},
}
