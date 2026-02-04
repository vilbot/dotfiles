return {
    { "nvim-lua/plenary.nvim" },
    { 
        "nvim-treesitter/nvim-treesitter", 
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.config").setup({
                ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "java" },
                sync_install = false,
                auto_install = false,
                highlight = {
                    enabled = true
                }
            })
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
    { "windwp/nvim-autopairs" },
    { "abecodes/tabout.nvim" },
    { "echasnovski/mini.surround" },
    { "mrjones2014/smart-splits.nvim" },
    { "mg979/vim-visual-multi" },
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
