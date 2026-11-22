#!/usr/bin/env bash
# Checks for the "None" desktop (tty/). Exit status 1 if anything is wrong.
#   - tty/hyprland.lua passes Hyprland's own check
#   - nothing outside tty/ mentions it, so None can't break or change the other desktops
#   - foot accepts tty/foot.ini, and None's generated colours are up to date
#   - None's keys (tty/keys.json): they parse, no keys twice (Hyprland's check above binds them
#     all: an unknown key or action fails it), keyd's Caps config
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL  $*"; fail=1; }
ok() { echo "ok    $*"; }

out=$(Hyprland --verify-config -c tty/hyprland.lua 2>&1 | sed -n '/parsing result/,$p' | tail -n +2)
if grep -q "config ok" <<<"$out"; then ok "tty/hyprland.lua"; else bad "tty/hyprland.lua:$out"; fi

refs=$(git grep --untracked -nP '(?<![\w.])tty/' -- . ':!tty/' ':!.gitignore' \
    ':!prompts/' ':!nvim_old/' ':!AGENTS.md' ':!README*' 2>/dev/null)
if [[ -z $refs ]]; then ok "nothing outside tty/ depends on it"; else bad "files outside tty/ use it:"$'\n'"$refs"; fi

if command -v foot >/dev/null; then
    python3 tty/theme.py ensure   # foot.ini includes the current theme's colours
    if err=$(foot -c tty/foot.ini --check-config 2>&1); then ok "tty/foot.ini"; else bad "tty/foot.ini: $err"; fi
else
    bad "foot not installed (pacman -S foot)"
fi

if python3 tty/theme.py build --check >/dev/null; then ok "None's gruver16 files (tty/theme.py build)"
else bad "colours out of date: python3 tty/theme.py build"; fi

for f in tty/*.sh tty/term tty/start tty/lock tty/bin/* tty/greeter/*.sh; do
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

# every theme has its 16 colours (tty/theme.py), and the panel's programs parse
if err=$(python3 - <<'PY' 2>&1
import ast, importlib.util
spec = importlib.util.spec_from_file_location("theme", "tty/theme.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
assert "gruver16" in m.names(), "no gruver16"
for n in m.names():
    t = m.load(n)
    assert len(m.ansi(t)) == 16, n
for f in ("tty/panel/update.py", "tty/panel/help.py", "tty/theme.py"):
    ast.parse(open(f).read(), f)
PY
); then ok "themes (tty/themes/*.yaml), tty/panel/update.py, help.py"; else bad "themes / panel programs: $err"; fi

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
cp tty/colors.lua "$tmp/"
machine=${XDG_CONFIG_HOME:-$HOME/.config}/none/machine.lua
[[ -f $machine ]] && cp -L "$machine" "$tmp/"
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
        || ! cmp -s tty/foot-colors.ini "$copy/foot-colors.ini" || ! cmp -s tty/colors.lua "$copy/colors.lua" \
        || { [[ -f $machine || -f $copy/machine.lua ]] && ! cmp -s "$machine" "$copy/machine.lua"; }; then
    bad "the login screen's copy is out of date: sudo tty/login.sh"
else ok "login screen copy (/etc/greetd/none) up to date"; fi

# None's keys (tty/keys.json, with yours over it): every key once, on the desktop and in each app (a desktop key
# never reaches an app); Hyprland's check above already bound them all
if err=$(python3 - <<'PY' 2>&1
import json
import os, pathlib
k = json.load(open("tty/keys.json"))
try:   # with what you changed laid over it (~/.config/none/keys.json)
    mine = json.loads((pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "none/keys.json").read_text())
except OSError:
    mine = {}
for group in k["sections"] + list(k.get("apps", {}).values()):
    for action, keys in mine.get("keys", {}).items():
        if action in group["actions"]:
            group["actions"][action]["keys"] = keys
n = mine.get("desktops", k.get("desktops", 5))
temps = {"{n}": [str(i) for i in range(1, n + 1)], "{dir}": list("HJKL"), "{arrow}": ["Left", "Down", "Up", "Right"]}
order = ["SUPER", "CTRL", "ALT", "SHIFT"]
def expand(key):
    parts = [p.strip() for p in key.split("+")]
    mods = sorted((m.upper() for m in parts[:-1]), key=order.index)
    last = parts[-1]
    names = temps.get(last, [last])
    return [" + ".join(mods + [x.upper() if len(x) == 1 else x]) for x in names]
def collect(groups):
    seen = {}
    for acts in groups:
        for action, d in acts.items():
            assert d.get("label"), f"{action}: no label"
            for key in d.get("keys", []):
                for e in expand(key):
                    assert e not in seen, f"{e}: both {seen[e]} and {action}"
                    seen[e] = action
    return seen
desk = collect(s["actions"] for s in k["sections"])
for app, a in k.get("apps", {}).items():
    mine = collect([a["actions"]])
    both = set(mine) & set(desk)
    assert not both, f"{app}: desktop keys never reach it: {sorted(both)}"
PY
); then ok "tty/keys.json"; else bad "tty/keys.json: $err"; fi
if command -v keyd >/dev/null; then
    if err=$(keyd check tty/keyd.conf 2>&1); then ok "tty/keyd.conf"; else bad "tty/keyd.conf: $err"; fi
    if ! systemctl is-active -q keyd; then echo "--    keyd isn't running: Caps is only Ctrl (sudo tty/keys.sh)"
    elif ! cmp -s tty/keyd.conf /etc/keyd/default.conf; then bad "keyd's config is out of date: sudo tty/keys.sh"
    else ok "keyd running with tty/keyd.conf"; fi
else echo "--    keyd not set up: Caps is only Ctrl (sudo tty/keys.sh)"; fi

# tty/caret (the layout at the text cursor): built, and not older than its source
bin=tty/caret/target/release/none-caret
if [[ ! -x $bin ]]; then bad "tty/caret isn't built: (cd tty/caret && cargo build --release)"
elif [[ -n $(find tty/caret/src tty/caret/Cargo.toml -newer "$bin") ]]; then bad "tty/caret changed since it was built: (cd tty/caret && cargo build --release)"
else ok "tty/caret built"; fi

exit $fail
