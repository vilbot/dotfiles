#!/usr/bin/env bash
# Checks for the "None" desktop (tty/). Exit status 1 if anything is wrong.
#   - tty/hyprland.lua passes Hyprland's own check
#   - the full desktop doesn't depend on tty/: only the theme generator (which writes
#     tty/foot-colors.ini) may mention it, so this experiment can't break or change the other desktops
#   - foot accepts tty/foot.ini, and its generated colours are up to date
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL  $*"; fail=1; }
ok() { echo "ok    $*"; }

out=$(Hyprland --verify-config -c tty/hyprland.lua 2>&1 | sed -n '/parsing result/,$p' | tail -n +2)
if grep -q "config ok" <<<"$out"; then ok "tty/hyprland.lua"; else bad "tty/hyprland.lua:$out"; fi

refs=$(git grep --untracked -nP '(?<![\w.])tty/' -- . ':!tty/' ':!.gitignore' ':!theme/build.py' \
    ':!prompts/' ':!nvim_old/' ':!AGENTS.md' ':!README*' 2>/dev/null)
if [[ -z $refs ]]; then ok "nothing outside tty/ depends on it"; else bad "files outside tty/ use it:"$'\n'"$refs"; fi

if command -v foot >/dev/null; then
    if err=$(foot -c tty/foot.ini --check-config 2>&1); then ok "tty/foot.ini"; else bad "tty/foot.ini: $err"; fi
else
    bad "foot not installed (pacman -S foot)"
fi

if python3 theme/build.py --check >/dev/null; then ok "tty/foot-colors.ini (theme/build.py)"
else bad "themes out of date: python3 theme/build.py"; fi

for f in tty/*.sh tty/term tty/start tty/bin/*; do
    bash -n "$f" 2>/dev/null || bad "$f: $(bash -n "$f" 2>&1)"
done && ok "shell scripts parse"

# every panel tab has its hints and binds, and no two actions share a key
if err=$(python3 - <<'PY' 2>&1
import importlib.util
spec = importlib.util.spec_from_file_location("panel", "tty/panel/panel.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
common = {"j", "k", "g", "G", "H", "L", "q", "tab"}
for name, tab in m.TABS.items():
    keys = [k for k, *_ in tab.actions.values()]
    assert len(keys) == len(set(keys)), f"{name}: a key is used twice: {keys}"
    assert not common & set(keys), f"{name}: takes a key every tab uses: {common & set(keys)}"
    for k, hint, method, *_ in tab.actions.values():
        assert callable(getattr(tab, method, None)), f"{name}: no method {method}"
PY
); then ok "tty/panel/panel.py"; else bad "tty/panel/panel.py: $err"; fi

exit $fail
