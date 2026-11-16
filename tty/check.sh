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

for f in tty/*.sh tty/term tty/start tty/desktops tty/bin/* tty/greeter/*.sh; do
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

# the boot splash and Limine's colours generate (into a temporary folder / from a sample config)
tmp=$(mktemp -d)
printf 'timeout: 3\nwallpaper: boot():/x.png\n/Entry\n    kernel_path: boot():/vmlinuz\n' >"$tmp/limine.conf"
if err=$(python3 tty/boot/plymouth.py "$tmp/ply" 2>&1 && python3 tty/boot/limine.py "$tmp/limine.conf" 2>&1) \
        && [[ -f $tmp/ply/none.script && -f $tmp/ply/block7.png ]] && grep -q '^term_palette: ' "$tmp/limine.conf" \
        && ! grep -q wallpaper "$tmp/limine.conf" && grep -q '^/Entry' "$tmp/limine.conf"
then ok "tty/boot (plymouth theme, limine colours)"; else bad "tty/boot: $err"; fi
rm -rf "$tmp"

# the login screen: its Hyprland config (with its /etc paths pointed at a temporary copy),
# and whether /etc/greetd/none still matches this repo (sudo tty/login.sh copies it)
tmp=$(mktemp -d)
cp hypr/colors.lua hypr/json.lua hypr/settings.json "$tmp/"
sed "s|^local here = .*|local here = \"$tmp/\"|" tty/greeter/greeter.lua >"$tmp/greeter.lua"
if out=$(Hyprland --verify-config -c "$tmp/greeter.lua" 2>&1) && grep -q "config ok" <<<"$out"
then ok "tty/greeter/greeter.lua"; else bad "tty/greeter/greeter.lua:"$'\n'"$out"; fi
rm -rf "$tmp"
if python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' tty/greeter/greeter.py 2>/dev/null
then ok "tty/greeter/greeter.py parses"; else bad "tty/greeter/greeter.py doesn't parse"; fi
copy=/etc/greetd/none
if [[ ! -d $copy ]]; then
    echo "--    login screen not set up (sudo tty/login.sh)"
elif { diff -rq tty/greeter "$copy" 2>/dev/null || true; } | grep -q '^Files' ||  # || true: pipefail would hide the match
        ! diff -rq tty/shell "$copy/shell" >/dev/null 2>&1 \
        || ! cmp -s tty/foot-colors.ini "$copy/foot-colors.ini"; then
    bad "the login screen's copy is out of date: sudo tty/login.sh"
else ok "login screen copy (/etc/greetd/none) up to date"; fi

exit $fail
