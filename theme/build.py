#!/usr/bin/env python3
"""Regenerate every app's gruver16 theme from theme/gruver16.yaml.

    python3 theme/build.py          # write all targets
    python3 theme/build.py --check  # exit 1 if any target is out of date (writes nothing)

Generated files (do NOT hand-edit, edit the yaml or a template instead):
    nvim/lua/palettes/gruver16.lua
    wezterm/colors/gruver16.toml
    ghostty/themes/gruver16
    zed/themes/gruver16.json        <- from theme/templates/zed.json ({{base0D}} tokens)
    jetbrains/gruver16/*            <- via jetbrains/build.py (reads the nvim palette)
"""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
THEME = ROOT / "theme"

pal = dict(re.findall(r'^(base0[0-9A-F]):\s*"([0-9a-fA-F]{6})"', (THEME / "gruver16.yaml").read_text(), re.M))
assert len(pal) == 16, f"expected 16 colors in gruver16.yaml, found {len(pal)}"
c = {k: "#" + v.lower() for k, v in pal.items()}
b = lambda n: c[f"base{n}"]

# Terminal ANSI mapping. Note: ANSI "yellow" is sage (0A) and "magenta" is the real yellow (0E).
# Shell configs pick colors by ANSI name, so zsh/pwsh use "magenta" for commands to get yellow.
ansi = [b("00"), b("08"), b("0B"), b("0A"), b("0D"), b("0E"), b("0C"), b("07")]
brights = [b("04")] + ansi[1:]
fg, bg, sel = b("07"), b("00"), b("02")


def nvim():
    rows = [list(c)[i:i + 4] for i in range(0, 16, 4)]
    body = "\n".join("  " + " ".join(f'{k} = "{c[k]}",' for k in r) for r in rows)
    return f"return {{\n{body}\n}}\n"


def wezterm():
    q = lambda xs: ", ".join(f'"{x}"' for x in xs)
    return (f'[colors]\nforeground = "{fg}"\nbackground = "{bg}"\ncursor_bg = "{fg}"\n'
            f'cursor_fg = "{bg}"\ncursor_border = "{fg}"\nselection_fg = "{fg}"\nselection_bg = "{sel}"\n\n'
            f'ansi  = [{q(ansi)}]\nbrights = [{q(brights)}]\n')


def ghostty():
    lines = [f"palette = {i}={x}" for i, x in enumerate(ansi + brights)]
    lines += [f"background = {bg}", f"foreground = {fg}", f"cursor-color = {fg}",
              f"cursor-text = {bg}", f"selection-background = {sel}", f"selection-foreground = {fg}"]
    return "\n".join(lines) + "\n"


def zed():
    tpl = (THEME / "templates/zed.json").read_text()
    out = re.sub(r"\{\{(base0[0-9A-F])\}\}", lambda m: pal[m.group(1)].lower(), tpl)
    left = re.findall(r"\{\{[^}]*\}\}", out)
    assert not left, f"unknown tokens in zed template: {left}"
    return out


targets = {
    "nvim/lua/palettes/gruver16.lua": nvim,
    "wezterm/colors/gruver16.toml": wezterm,
    "ghostty/themes/gruver16": ghostty,
    "zed/themes/gruver16.json": zed,
}

check = "--check" in sys.argv
stale = []
for rel, gen in targets.items():
    path, new = ROOT / rel, gen()
    if path.exists() and path.read_text() == new:
        continue
    stale.append(rel)
    if not check:
        path.write_text(new)
        print("wrote", rel)

if check:
    if stale:
        print("out of date:", *stale, sep="\n  ")
        sys.exit(1)
    print("all themes up to date")
    sys.exit(0)

# JetBrains reads the nvim palette we just wrote. Only rebuild when the palette changed,
# since the plugin zip is binary and would otherwise churn on every run.
if "nvim/lua/palettes/gruver16.lua" in stale or "--jetbrains" in sys.argv:
    subprocess.run([sys.executable, str(ROOT / "jetbrains/build.py")], check=True)
    print("rebuilt jetbrains theme")

if not stale:
    print("nothing changed")
