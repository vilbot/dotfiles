-- This machine's monitors and keyboard, for None (~/.config/none/machine.lua). None's login
-- screen runs it too (a copy: `sudo login.sh` in None's folder after a change), so only
-- monitors and input here.

-- by description: connector names change (DP-4 became DP-1 with NVIDIA loading early)
hl.monitor({ output = "desc:Sony SONY TV", mode = "preferred", position = "auto", scale = 1, mirror = "desc:Samsung Electric Company LS27FG53x" })
hl.monitor({ output = "desc:Samsung Electric Company LS27FG53x", mode = "2560x1440@200.00", position = "auto", scale = 1 })

hl.config({ input = {
    kb_layout = "us,se",
    kb_variant = ",swerty",
    kb_options = "ctrl:nocaps,lv3:ralt_switch",   -- right Alt = AltGr: swerty's ;:'"[]{} (the US layout's Alt_R otherwise wins)
} })
