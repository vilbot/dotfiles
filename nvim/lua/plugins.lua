return {
    { "nvim-lua/plenary.nvim" },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            local status, ts_config = pcall(require, "nvim-treesitter.configs")
            if not status then
                status, ts_config = pcall(require, "nvim-treesitter.config")
            end
            if status then
                ts_config.setup({
                    ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "java" },
                    sync_install = false,
                    auto_install = false,
                    highlight = {
                        enabled = true
                    }
                })
            else
                print("Treesitter could not be loaded, skipping setup")
            end
        end
    },
    {
        "stevearc/oil.nvim",
        config = function() 
            require("oil").setup({
                skip_confirm_for_simple_edits = true,
                view_options = {
                    show_hidden = true
                }
            })
        end
    },
    { 
        "abecodes/tabout.nvim",
        config = function()
            require("tabout").setup({
                tabouts = {
                    { open = "'", close = "'" },
                    { open = '"', close = '"' },
                    { open = '`', close = '`' },
                    { open = '(', close = ')' },
                    { open = '[', close = ']' },
                    { open = '{', close = '}' },
                    { open = ":", close = ")" },
                }
            })
        end
    },
    { "windwp/nvim-autopairs", config = function () require("nvim-autopairs").setup({}) end },
    { "echasnovski/mini.surround", config = function () require("mini.surround").setup({}) end },
    { "mrjones2014/smart-splits.nvim", config = function () require("smart-splits").setup({}) end },
    -- { "mg979/vim-visual-multi", config = function () require("vim-visual-multi").setup({}) end },
    {
        "blazkowolf/gruber-darker.nvim",
        priority = 1000,
        config = function()
            require("gruber-darker").setup({
                bold = false,
                italic = {
                    comments = false,
                    strings = false,
                    keywords = false,
                    operators = false
                },
            })
            vim.cmd.colorscheme("gruber-darker")
        end
    },
    { 
        "nvim-telescope/telescope.nvim", 
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("telescope").setup({
                defaults = {
                    layout_strategy = "horizontal",
                    layout_config = {
                        prompt_position = "top"
                    },
                    sorting_strategy = "ascending",
                    selection_caret = "☞ ", -- ➤
                    mappings = {
                        i = {
                            ["<C-s>"] = "select_horizontal",
                        },
                        n = {
                            ["<C-s>"] = "select_horizontal",
                        }
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
                        theme = "dropdown",
                        previewer = false,
                    },
                    colorscheme = {
                        enable_preview = true
                    }
                }
            })
        end
    },
    { "mason-org/mason.nvim" },
    { "mason-org/mason-lspconfig.nvim" },
    { "neovim/nvim-lspconfig" },
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-buffer" },
    { "saadparwaiz1/cmp_luasnip" },
    { "L3MON4D3/LuaSnip" },
    { "rafamadriz/friendly-snippets" },
    {
        "basola21/PDFview",
        lazy = false,
        dependencies = { "nvim-telescope/telescope.nvim" }
    },
}
