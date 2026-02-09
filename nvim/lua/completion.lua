-- lua/completion.lua
local cmp = require('cmp')
local luasnip = require('luasnip')

-- Load 'friendly-snippets' (contains sout, psvm, etc.)
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    -- MAPPINGS
    mapping = cmp.mapping.preset.insert({
        -- 1. TRIGGER: Force menu open
        ['<C-l>'] = cmp.mapping.complete(),

        -- 2. ACCEPT with ENTER (Standard)
        ['<CR>'] = cmp.mapping.confirm({ select = true }),

        -- 3. NAVIGATE (Standard Vim)
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),

        -- 4. THE SUPER-TAB
        ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
                -- A. If menu is open, Accept selection
                cmp.confirm({ select = true })
            elseif luasnip.expand_or_jumpable() then
                -- B. If menu is closed, Jump to next snippet placeholder
                luasnip.expand_or_jump()
            else
                -- C. Otherwise, regular Tab
                fallback()
            end
        end, { 'i', 's' }),

        -- 5. SHIFT-TAB (Go backwards in snippet)
        ['<S-Tab>'] = cmp.mapping(function(fallback)
            if luasnip.jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, { 'i', 's' }),
    }),

    -- SOURCES (Order matters)
    sources = cmp.config.sources({
        { name = 'nvim_lsp' }, -- Java smarts
        { name = 'luasnip' },  -- Snippets (sout, psvm)
        { name = 'buffer' },   -- Text in file
    })
})

-- === EXCEPTION FOR C/C++ ===
-- Disable auto-completion popup for C files.
-- You must press <C-Space> to see it.

-- cmp.setup.filetype({ "c", "cpp" }, {
--     completion = {
--         autocomplete = false
--     }
-- })
