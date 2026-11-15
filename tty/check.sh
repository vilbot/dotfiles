#!/usr/bin/env bash
# Checks for the "None" desktop (tty/). Exit status 1 if anything is wrong.
#   - tty/hyprland.lua passes Hyprland's own check
#   - the full desktop doesn't depend on tty/: only the login (.zprofile) and install.sh may
#     mention it, so this experiment can't break or change the other desktops
#   - foot accepts tty/foot.ini, and its font was built from the console's font
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL  $*"; fail=1; }
ok() { echo "ok    $*"; }

out=$(Hyprland --verify-config -c tty/hyprland.lua 2>&1 | sed -n '/parsing result/,$p' | tail -n +2)
if grep -q "config ok" <<<"$out"; then ok "tty/hyprland.lua"; else bad "tty/hyprland.lua:$out"; fi

refs=$(git grep --untracked -nP '(?<![\w.])tty/' -- . ':!tty/' ':!.zprofile' ':!install.sh' \
    ':!prompts/' ':!nvim_old/' ':!AGENTS.md' ':!README*' 2>/dev/null)
if [[ -z $refs ]]; then ok "nothing outside tty/ depends on it"; else bad "files outside tty/ use it:"$'\n'"$refs"; fi

if command -v foot >/dev/null; then
    if err=$(foot -c tty/foot.ini --check-config 2>&1); then ok "tty/foot.ini"; else bad "tty/foot.ini: $err"; fi
else
    bad "foot not installed (pacman -S foot)"
fi

font=~/.local/share/fonts/tty-console.ttf
want=$(sed -n 's/^FONT="\?\([^"]*\)"\?/\1/p' /etc/vconsole.conf 2>/dev/null)
want=${want:-ter-v32n}
have=$(python3 -c "from fontTools.ttLib import TTFont; print(TTFont('$font')['name'].getDebugName(5))" 2>/dev/null)
if [[ $have == *"from $want."* ]]; then ok "console font $want -> $font"
else bad "$font isn't built from $want (python3 tty/psf2ttf.py)"; fi
grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null || echo "note  /etc/vconsole.conf has no FONT=, the console uses the kernel's own font"

exit $fail
