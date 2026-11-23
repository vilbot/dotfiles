# Merge notes: Mac → Linux (delete this file once the merge is done)

The Mac pushed these commits to `origin/main`. Linux `main` has ~45 local commits on top of an
older base. Merge (don't rebase): `git fetch && git merge origin/main`. Don't push until the user says so.

## What changed on the Mac
- **nvim colorscheme layout:** `nvim/colors/custom.lua` is gone. Its whole body (all slot → group
  mappings) moved to `nvim/lua/util/colorscheme.lua`, which is `return function(name) ... end`.
  `nvim/colors/gruver16.lua` and `nvim/colors/gruvnord.lua` are one-liners:
  `require("util.colorscheme")("<name>")`. The colorscheme is now called `gruver16`, not `custom`
  (`init.lua` and `lua/config/lazy.lua` updated).
- **Blend colors:** no longer hand-written in the colorscheme. `theme/build.py` mixes Zed's alpha
  colors (from `theme/templates/zed.json`) over base00 and writes them into each
  `nvim/lua/palettes/<name>.lua` as `blend = { active_line, selection, match, active_match }`.
  The colorscheme uses `c.blend`.
- **`theme/build.py`** builds every `theme/*.yaml` (each theme gets `<name>`-named outputs) and
  accepts hex values with or without `#`. The zed template uses a `{{Name}}` token for the theme name.
- **`jetbrains/build.py [name]`** takes the theme name; output goes to `jetbrains/<name>/`.
- **New theme `gruvnord`:** `theme/gruvnord.yaml` (gruver16 slot roles, Nord palette) and its
  generated files.
- **New plugin:** `brenoprata10/nvim-highlight-colors` in `nvim/lua/plugins/ui.lua`.
- Removed the old, unused `nvim/colors/gruver16.lua` (the 81-line one). The new `gruver16.lua` is the wrapper.

## Resolving conflicts
- `nvim/colors/custom.lua`: keep the Mac layout. Carry any Linux edits to the mappings into
  `nvim/lua/util/colorscheme.lua`. Linux's computed-blend code at the top is replaced by `c.blend`.
- `theme/build.py`: keep the Mac version, re-apply anything else Linux changed in it.
- `AGENTS.md`: keep the Mac "Colors: gruver16 family" section, merge the rest.
- `nvim/lazy-lock.json`: take either side, then `:Lazy restore` / `:Lazy update`.
- Anything else Linux renamed or added that references `custom` or `palettes.gruver16`: update it.

## Check
1. `python3 theme/build.py` then `python3 theme/build.py --check`.
2. `nvim --headless "+colorscheme gruver16" +qa` and the same for `gruvnord`, with no errors.
3. Delete this file and commit.
