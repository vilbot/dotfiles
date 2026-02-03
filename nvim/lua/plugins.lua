return {
    -- Core & Utils
    { "nvim-lua/plenary.nvim" },
    { "stevearc/oil.nvim" },
    { "windwp/nvim-autopairs" },
    { "abecodes/tabout.nvim" },
    { "echasnovski/mini.surround" },
    { "mrjones2014/smart-splits.nvim" },
    { "mg979/vim-visual-multi" },

    -- UI / Theme
    { "blazkowolf/gruber-darker.nvim" },

    -- Treesitter
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

    -- Telescope
    { 
        "nvim-telescope/telescope.nvim", 
        branch = "0.1.x",
        dependencies = { "nvim-lua/plenary.nvim" } 
    },

    -- LSP & Mason
    { "mason-org/mason.nvim" },
    { "mason-org/mason-lspconfig.nvim" },
    { "neovim/nvim-lspconfig" },

    -- Autocompletion & Snippets
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-buffer" },
    { "saadparwaiz1/cmp_luasnip" },
    { "L3MON4D3/LuaSnip" },
    { "rafamadriz/friendly-snippets" },
}
