# Neovim config

Runs on macOS, Linux and Windows. Needs Neovim 0.12 or newer.

## Layout

```
init.lua                 load order only
colors/custom.lua        active colorscheme (palettes are in lua/palettes/)
after/lsp/<server>.lua   settings for one language server
zed-queries/<lang>.scm   Zed's treesitter highlight queries
lua/config/
  platform.lua           OS checks: is_win, is_mac, is_linux, is_arm
  options.lua            leader, options, filetypes, Windows shell setup
  lazy.lua               lazy.nvim bootstrap
  autocmds.lua           editor autocmds
  keymaps.lua            editor keymaps
  lsp.lua                LspAttach keymaps, capabilities, format on save
lua/plugins/             one file per topic, each returns lazy.nvim specs
lua/util/                helpers: terminal toggle, build script runner
```

## Extending

**Add a plugin.** Create or edit any file in `lua/plugins/`. Every file there is imported
automatically. Keep the plugin's keymaps, autocmds and options in its spec:

```lua
-- lua/plugins/example.lua
return {
	{
		"author/plugin.nvim",
		opts = {},
		keys = {
			{ "<leader>x", function() require("plugin").run() end, desc = "Run plugin" },
		},
	},
}
```

A spec with `keys`, `cmd` or `event` is lazy-loaded. Add `lazy = false` if the plugin has
to be there at startup.

**Add a language server.** Add its name to `ensure_installed` in `lua/plugins/lsp.lua`. For
custom settings, add `after/lsp/<name>.lua` returning a `vim.lsp.Config` table. It merges over
the defaults from nvim-lspconfig. Use `after/lsp/`, not `lsp/`: a file in `lsp/` loads before
nvim-lspconfig and its values get overwritten.

For a server Mason does not provide, call `vim.lsp.enable("name")` in `lua/config/lsp.lua`.

**Add a treesitter parser.** Add it to `ensure_installed` in `lua/plugins/treesitter.lua`.

**Add a whole language.** Create one file that extends both lists:

```lua
-- lua/plugins/rust.lua
return {
	{ "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "rust" } } },
	{ "mason-org/mason-lspconfig.nvim", opts = { ensure_installed = { "rust_analyzer" } } },
}
```

**Format a file type on save.** Add a glob to `format_on_save` in `lua/config/lsp.lua`.

**Add OS-specific behaviour.** Branch on `require("config.platform")`.

## Colors

`zed/themes/gruver16.json` is the source of truth. Neovim matches it in three parts:

- `colors/custom.lua` holds a copy of the theme's `syntax` block.
- `zed-queries/<lang>.scm` holds Zed's queries for that language, which decide which capture
  each token gets. They replace nvim-treesitter's queries completely. Languages without a file
  there keep nvim-treesitter's queries.
- LSP semantic tokens are off, as in Zed's defaults.

To bring in a change from Zed:

- **Theme colors:** update `colors/custom.lua` and `lua/palettes/gruver16.lua`.
- **Queries:** copy the new `highlights.scm` over the file in `zed-queries/`. Each file's first
  line says where it came from. `java.scm` also needs `zed/patches/java-highlights.sh` applied,
  which is already done if you copy Zed's installed extension file.
- **New language:** add `zed-queries/<lang>.scm`, using the parser's name for `<lang>`.

## Keymaps that differ by OS

| Action                  | macOS   | Windows and Linux |
| ----------------------- | ------- | ----------------- |
| Terminal, bottom split  | `<D-j>` | `<leader>j`       |
| Terminal, side split    | `<D-k>` | `<leader>k`       |
| Terminal, current window| none    | `<leader>t`       |

## Setup

External tools:

- `git`, for lazy.nvim and plugins.
- `rg`, for Telescope grep and file search.
- `tree-sitter` CLI and a C compiler, to install parsers.
- JDK 21 or newer for `jdtls`. A JDK newer than the `jdtls` release crashes it on startup:
  JDK 27 needs `jdtls` 1.63 or newer, so update it in `:Mason`. Mason does not update
  servers on its own. The config looks at `C:/Program Files/Java/jdk-2[1-9]*` on Windows,
  then `JAVA_HOME`, then `java` on `PATH`.
- Node.js for `ts_ls` and the HTML and CSS servers.
- `pdftotext`, for PDFview.
- A Nerd Font, for icons.

Link this directory to the config path:

```sh
ln -s ~/dotfiles/nvim ~/.config/nvim                       # macOS and Linux
```

```bat
mklink /D %LOCALAPPDATA%\nvim %USERPROFILE%\dotfiles\nvim  &:: Windows, as administrator
```

Plugins and language servers install on first launch.

The C# server is not in `ensure_installed`. Install it with `:MasonInstall roslyn`, it comes
from the extra registry set in `lua/plugins/lsp.lua`.
