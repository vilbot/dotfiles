-- Settings per file type. Save this file and they apply right away.
-- :FiletypeSettings opens it at the entry for the file you're in, adding one if needed.
--
-- Options (leave one out to keep your normal setting from config/options.lua):
--   tab_size = 2                  width of one indent level
--   hard_tabs = false             true: indent with tabs, false: indent with spaces
--   detect_indent = true          false: ignore the indent in the file and its neighbours
--   soft_wrap = true              wrap long lines on screen
--   line_numbers = true           show line numbers
--   relative_line_numbers = true  show line numbers relative to the cursor
--   spell = true                  spell check
--   text_width = 80               break lines at this width while typing
--   ruler = 80                    draw a vertical line at this column
--
-- Which indent wins, strongest first:
--   1. A modeline or .editorconfig
--   2. The file's existing indent, then other files of that type nearby (detect_indent)
--   3. tab_size and hard_tabs here
--
-- Names are Neovim file types, which aren't always the extension (.jsx is javascriptreact).
-- :set filetype? shows the current one.
return {
	javascript = { tab_size = 2, hard_tabs = false },
	javascriptreact = { tab_size = 2, hard_tabs = false },
	typescript = { tab_size = 2, hard_tabs = false },
	typescriptreact = { tab_size = 2, hard_tabs = false },
	html = { tab_size = 2, hard_tabs = false },
	css = { tab_size = 2, hard_tabs = false },
	json = { tab_size = 2, hard_tabs = false },
}
