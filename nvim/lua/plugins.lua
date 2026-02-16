return {
    { "nvim-lua/plenary.nvim" },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require('nvim-treesitter.config').setup({
                ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "java" },
                sync_install = false,
                auto_install = true,
                highlight = { enable = true },
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
    { "mason-org/mason.nvim" },
    { "mason-org/mason-lspconfig.nvim" },
    { "neovim/nvim-lspconfig" },
    {
        'saghen/blink.cmp',
        version = 'v0.*',
        dependencies = { 'rafamadriz/friendly-snippets' },
        opts = {
            fuzzy = {
                prebuilt_binaries = {
                    download = true,
                    force_version = nil,
                }
            },
            appearance = {
                -- 'mono' () for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
                -- Adjusts spacing to ensure icons are aligned
                nerd_font_variant = 'mono'
            },
            -- *blink-keymaps*
            keymap = {
                preset = 'super-tab',
                ['<C-n>'] = { 'show', 'select_next', 'fallback' },
                -- ['<C-p>'] = { 'hide', 'select_prev', 'fallback' },
            },
            completion = {
                menu = {
                    auto_show = function()
                        return not vim.tbl_contains({ "c", "cpp" }, vim.bo.filetype)
                    end,
                    draw = {
                        padding = { 0, 1 }, -- padding only on right side
                        components = {
                            kind_icon = {
                                text = function(ctx) return ' ' .. ctx.kind_icon .. ctx.icon_gap .. ' ' end
                            }
                        }
                    }
                },
            }
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
                    theme = "dropdown",
                    previewer = false,
                },
                live_grep = {

                },
                grep_string = {

                },
                registers = {
                    theme = "cursor",

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
        }
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

    -- THEMES --
    {
        "blazkowolf/gruber-darker.nvim",
        priority = 1000,
        lazy = false,
        config = function(_, opts)
            require("gruber-darker").setup(opts)
            vim.cmd.colorscheme("gruber-darker")
        end,

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
    { "rebelot/kanagawa.nvim" },
    { "Mofiqul/vscode.nvim" },
    { "shaunsingh/nord.nvim" },
    { "AlexvZyl/nordic.nvim" },
    { "jacoborus/tender.vim" },
    { "savq/melange-nvim" },
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
