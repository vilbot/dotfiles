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
                compilers = { "zig" },
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
        opts = {
            fuzzy = { implementation = 'lua' },
            appearance = {
                -- 'mono' () for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
                -- Adjusts spacing to ensure icons are aligned
                nerd_font_variant = 'mono',
                use_nvim_cmp_as_default = true,
            },
            -- *blink-keymaps*
            keymap = {
                preset = 'default',
                ['<C-f>'] = { 'select_and_accept', 'fallback'},
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
                    auto_show = false, -- function() return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) end,
                    draw = {
                        padding = { 0, 1 },
                        components = {
                            kind_icon = { text = function(ctx) return ' ' .. ctx.kind_icon .. ctx.icon_gap .. ' ' end }
                        },
                    },
                    border = "rounded",
                    winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
                },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 2000,
                    window = {
                        border = "rounded",
                        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
                    },
                },
                ghost_text = {
                    enabled = true -- function() return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype) end,
                },
            },
            signature = {
                enabled = false,
                trigger = {
                    enabled = true,
                    show_on_insert = true,
                },
            },
        },
    },
    {
        "kawre/neotab.nvim",
        event = "InsertEnter",
        opts = {
            -- configuration goes here
        },
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
                        -- find_files = {
                            --     theme = "cursor",
                            --     previewer = false,
                            -- },
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
}
