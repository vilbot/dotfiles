require("nvim-treesitter.configs").setup({
    ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "java" },
    sync_install = false,
    auto_install = false,
    highlight = {
        enabled = true
    }
})

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

require("oil").setup({
    skip_confirm_for_simple_edits = true,
    view_options = {
        show_hidden = true
    }
})
require("nvim-autopairs").setup({})
require("tabout").setup({})
require("mini.surround").setup({})
require("smart-splits").setup({})

require("gruber-darker").setup({
    bold = false,
    italic = {
        comments = false,
        strings = false,
        keywords = false,
        operators = false
    },
})

vim.api.nvim_set_hl(0, "VM_Mono",   { link = "Visual" })
vim.api.nvim_set_hl(0, "VM_Extend", { link = "Visual" })
vim.api.nvim_set_hl(0, "VM_Cursor", { link = "Cursor" })
vim.api.nvim_set_hl(0, "VM_Insert", { link = "IncSearch" })

