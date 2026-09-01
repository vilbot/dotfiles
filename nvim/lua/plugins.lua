return {
    { "nvim-lua/plenary.nvim" },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require('nvim-treesitter.config').setup({
                install_dir = "C:\\Users\\Vilgot\\AppData\\Local\\nvim-data\\site\\parser",
                ensure_installed = { "razor", "html", "css", "c", "cpp", "c_sharp", "lua", "vim", "vimdoc", "query", "java" },
                sync_install = false,
                auto_install = true,
                highlight = { enable = true },
                prefer_git = false, 
                compilers = { "zig" }, -- I dont have the zig compiler installed anymore
            })

            -- without this colors dont load properly
            vim.api.nvim_create_autocmd("FileType", {
                callback = function()
                    if vim.bo.buftype == "" then
                        pcall(vim.treesitter.start)
                    end
                end,
            })
        end
    },
    { 
        "mason-org/mason.nvim",
        opts = {
            registries = {
                "github:mason-org/mason-registry",
                "github:Crashdummyy/mason-registry",
            },
        }
    },
    { "mason-org/mason-lspconfig.nvim" },
    {
        "seblyng/roslyn.nvim",
        ---@module 'roslyn.config'
        ---@type RoslynNvimConfig
        opts = {

        },
    },
    { "neovim/nvim-lspconfig" },
    {
        'saghen/blink.cmp',
        version = 'v0.*',
        dependencies = { 'rafamadriz/friendly-snippets' },

        opts = function()
          return {
            fuzzy = {
				implementation = 'lua',
				sorts = (function()
					local k = require('blink.cmp.types').CompletionItemKind
					-- lower number = higher in the list
					local modified_priority = {
						[k.Field] = 1,
						[k.Property] = 1,
						[k.Method] = 2,
						[k.Variable] = 3,
						[k.Function] = 3,
						[k.EnumMember] = 4,
						[k.Constant] = 4,
						[k.Keyword] = 90,
						[k.Snippet] = 95,
						[k.Text] = 100,
					}
					local function modified_kind(kind)
						return modified_priority[kind] or 50
					end

					return {
						'exact',
						function(a, b) -- members/fields before snippets, keywords, text
							local kind1 = modified_kind(a.kind)
							local kind2 = modified_kind(b.kind)
							if kind1 ~= kind2 then
								return kind1 < kind2
							end
						end,
						'score',
						'sort_text',
					}
				end)(),
			},
            sources = {
                -- after a member-access operator, or mid-statement, only the LSP
                -- has anything meaningful to say -- snippets/buffer are noise there
                default = function()
                    local col = vim.api.nvim_win_get_cursor(0)[2]
                    local before = vim.api.nvim_get_current_line():sub(1, col)

                    if before:match('[%w_%)%]"\']%s*%.%s*[%w_]*$')
                        or before:match('->%s*[%w_]*$')
                        or before:match('::%s*[%w_]*$')
                        or before:match('[%w_]:%s*[%w_]*$')
                    then
                        return { 'lsp' }
                    end

                    -- not at the start of a statement -> no snippet templates
                    if before:match('%S%s+[%w_]*$') then
                        return { 'lsp', 'path', 'buffer' }
                    end

                    return { 'lsp', 'path', 'snippets', 'buffer' }
                end,
            },
            appearance = {
                -- 'mono' () for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
                -- Adjusts spacing to ensure icons are aligned
                nerd_font_variant = 'mono',
                use_nvim_cmp_as_default = true,
            },
            -- *blink-keymaps*
            keymap = {
                preset = 'default',
                ['<Tab>'] = { 'select_and_accept', 'snippet_forward', 'fallback'},
				['<CR>']  = { 'select_and_accept', 'fallback'},
                ['<C-n>'] = { 'show', 'select_next', 'fallback' },
                ['<C-e>'] = { 'hide', 'show', 'fallback' },
            },
            completion = {
                list = {
                    selection = {
                        preselect = true, -- function() return not require('blink.cmp').snippet_active({ direction = 1 }) end,
                        auto_insert = false,
                    },
                },
                menu = {
                    auto_show = true, -- function() return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) end,
                    draw = {
                        padding = { 0, 1 },
                        components = {
                            kind_icon = { text = function(ctx) return ' ' .. ctx.kind_icon .. ctx.icon_gap .. ' ' end }
                        },
                    },
                    border = "rounded",
					winhighlight = 'Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
                },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 1000,
                    window = {
                        border = "rounded",
						winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc',
                    },
                },
                ghost_text = {
                    enabled = function() return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) end,
                },
            },
            signature = {
                enabled = false,
                trigger = {
                    enabled = true,
                    show_on_insert = true,
                },
            },
          }
        end,
    },
	-- {
	-- 	"cyuria/build.nvim",
	-- 	event = { "DirChanged", "BufRead" },
	-- 	opts = {}
	-- },
    {
        "kawre/neotab.nvim",
        event = "InsertEnter",
        opts = {
            -- configuration goes here
        },
    },
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		---@module "ibl"
		---@type ibl.config
		opts = {
			indent = {
				char = "│",                  -- Regular indent line character
				highlight = { "IblIndent" }, -- Map the regular line to your color group
			},
			scope = {
				enabled = true,
				show_exact_scope = true,
				char = "│",                  -- Active scope line character
				highlight = { "IblScope" },  -- Map the active scope to your color group
				show_start = false,
				show_end = false,
				include = {
					node_type = {
						cpp = { "case_statement" },
						c = { "case_statement" },
					},
				}
			},
		},
		config = function(_, opts)
			local hooks = require("ibl.hooks")
			
			-- This hook safely creates colors and protects them from being wiped by your theme
			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "IblIndent", { fg = "#444444" })
				vim.api.nvim_set_hl(0, "IblScope", { fg = "#575757" })
				-- vim.api.nvim_set_hl(0, "IblIndent", { fg = palette.base02 })
				-- vim.api.nvim_set_hl(0, "IblScope", { fg = palette.base03 })
			end)

			-- Load the plugin config
			require("ibl").setup(opts)
		end,
	},
	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async",
		config = function()
			-- Enable the margin column for folds
			vim.o.foldcolumn = '1'
			vim.o.foldlevel = 99 
			vim.o.foldlevelstart = 99
			vim.o.foldenable = true
			
			-- Set fold characters to '+' and '-', and turn off the vertical separator line
			vim.o.fillchars = [[eob: ,fold: ,foldopen:-,foldsep: ,foldclose:+,foldinner: ]]
			
			-- Compact status column spacing
			-- vim.o.statuscolumn = "%= %l %s%C"

			require("ufo").setup({
				open_fold_hl_timeout = 200, 
				provider_selector = function(bufnr, filetype, buftype)
					return { "treesitter", "indent" }
				end,
			})
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" }, 
		config = function()
			require("gitsigns").setup({
				-- Define the conventional text icons for the sidebar
				signs = {
					add          = { text = "┃" }, -- Green bar
					change       = { text = "┃" }, -- Yellow bar
					delete       = { text = "_" }, -- Red floor bar
					topdelete    = { text = "‾" }, -- Red ceiling bar
					changedelete = { text = "~" }, -- Yellow/Red mixed bar
					untracked    = { text = "┆" },
				},
				signs_staged = {
					add          = { text = "┃" }, -- Green bar
					change       = { text = "┃" }, -- Yellow bar
					delete       = { text = "_" }, -- Red floor bar
					topdelete    = { text = "‾" }, -- Red ceiling bar
					changedelete = { text = "~" }, -- Yellow/Red mixed bar
					untracked    = { text = "┆" },
				},
				-- Map them to the conventional colors (if your theme doesn't do it automatically)
				signcolumn = true, 

				on_attach = function(bufnr)
					vim.schedule(function()
						if vim.api.nvim_buf_is_valid(bufnr) then
							vim.cmd("redrawstatus")
						end
					end)
				end
			})
		end,
	},
	{
		'luukvbaal/statuscol.nvim', 
		dependencies = { "lewis6991/gitsigns.nvim" },
		lazy = false,
		config = function()
			local builtin = require('statuscol.builtin')
			require('statuscol').setup({
				setopt = true,
				relculright = true,
				segments = {
					{
						sign = {
							namespace = { "gitsigns" }, -- Matches the gitsigns namespace
							maxwidth = 1,
							colwidth = 1,
							auto = false,                -- Column disappears if no git changes exist
						},
						click = "v:lua.ScSa",         -- Links native click handlers to preview/stage hunks
					},
					{
						text = { builtin.lnumfunc },
						click = "v:lua.ScSa",         -- Links native click handlers to preview/stage hunks
					},
					{ text = { " " } },
					-- { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
					{ text = { " " } },
					{ text = { builtin.foldfunc }, click = "v:lua.ScFa" },
					{ sign = { name = { ".*" }, maxwidth = 2, colwidth = 1, auto = true }, click = "v:lua.ScSa" },
				}
			})
		end,
	},
	{ "windwp/nvim-autopairs", config = function () require("nvim-autopairs").setup({}) end },
	{ "echasnovski/mini.surround", config = function () require("mini.surround").setup({}) end },
	{ "mrjones2014/smart-splits.nvim", config = function () require("smart-splits").setup({}) end },
	{
		"nvim-telescope/telescope.nvim", 
		branch = 'master',
		-- branch = "0.1.x",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function ()
			require("telescope").setup({
				-- opts = {
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
					-- }

				})
			end
		},
		{
			"stevearc/oil.nvim",
			opts = {
				skip_confirm_for_simple_edits = true,
				view_options = {
					show_hidden = true
				},
			}
		},
		{
			"nvim-tree/nvim-tree.lua",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			config = function()
				require("nvim-tree").setup()
			end
		},
		{
			"basola21/PDFview",
			lazy = false,
			dependencies = { "nvim-telescope/telescope.nvim" }
		},
		{
			"nvim-lualine/lualine.nvim",
			dependencies = { 'nvim-tree/nvim-web-devicons' },
			opts = {

			}
		},
		{
			"folke/snacks.nvim",
			priority = 1000,
			lazy = false,
			opts = {
				terminal = {
					shell = "C:/Program Files/Git/usr/bin/bash.exe",
				},
			},
		},
		{
			"coder/claudecode.nvim",
			dependencies = { "folke/snacks.nvim" },
			opts = {
				terminal = {
					provider = "native",
				},
			},
		},
		-- COLORSCHEMES --
		{
			"blazkowolf/gruber-darker.nvim",
			priority = 1000,
			lazy = false,

			opts = {
				bold = false,
				italic = {
					comments = false,
					strings = false,
					keywords = false,
					operators = false
				},
			}
		},
		{
			"https://github.com/luisiacc/handmade-hero-theme"
		},
		{
			"ellisonleao/gruvbox.nvim",
			config = true,
			priority = 1000,
			lazy = false,

			opts = {
				bold = false,
				italic = {
					comments = false,
					strings = false,
					keywords = false,
					operators = false
				},
			}
		},
		{ 
			"rebelot/kanagawa.nvim",
			opts = {
				commentStyle = { italic = false },
				keywordStyle = { bold = false},
				statementStyle = { bold = false },
			}
		},
		{ "Mofiqul/vscode.nvim" },
		{ "shaunsingh/nord.nvim" },
		{ "AlexvZyl/nordic.nvim" },
		{ "jacoborus/tender.vim" },
		{ "savq/melange-nvim" },
		{ "tanvirtin/monokai.nvim" },
		{
			'datsfilipe/vesper.nvim',
			priority = 1000,
			opts = {
				transparent = true, -- Boolean: Sets the background to transparent
				italics = {
					comments = false, -- Boolean: Italicizes comments
					keywords = false, -- Boolean: Italicizes keywords
					functions = false, -- Boolean: Italicizes functions
					strings = false, -- Boolean: Italicizes strings
					variables = false, -- Boolean: Italicizes variables
				},
				bold = false
			}
		},
		{
			"srcery-colors/srcery-vim",
			lazy = false,
			priority = 1000,
		},
	}
