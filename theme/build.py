#!/usr/bin/env python3
"""Regenerate every app's theme from each theme/<name>.yaml (gruver16, gruvnord, ...).

    python3 theme/build.py          # write all targets
    python3 theme/build.py --check  # exit 1 if any target is out of date (writes nothing)

Generated files per theme (do NOT hand-edit, edit the yaml or a template instead):
    nvim/lua/palettes/<name>.lua     <- also holds `blend`, Zed's alpha colors flattened
    wezterm/colors/<name>.toml
    ghostty/themes/<name>
    zed/themes/<name>.json           <- from theme/templates/zed.json ({{base0D}}, {{Name}} tokens)
    jetbrains/<name>/*               <- via jetbrains/build.py (reads the nvim palette)
"""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
THEME = ROOT / "theme"
ZED_TPL = (THEME / "templates/zed.json").read_text()

# nvim can't do alpha, so these Zed colors are mixed over base00 and stored in the nvim palette.
BLEND = {
    "active_line": "editor.active_line.background",
    "selection": None,  # players[0].selection
    "match": "search.match_background",
    "active_match": "search.active_match_background",
}


def zed_color(key):
    if key is None:
        m = re.search(r'"selection":\s*"#\{\{(base0[0-9A-F])\}\}([0-9a-f]{2})"', ZED_TPL)
    else:
        m = re.search(rf'"{re.escape(key)}":\s*"#\{{\{{(base0[0-9A-F])\}}\}}([0-9a-f]{{2}})"', ZED_TPL)
    assert m, f"zed template has no {{{{baseXX}}}}+alpha value for {key or 'players[0].selection'}"
    return m.group(1), int(m.group(2), 16) / 255


def mix(fg, bg, a):
    ch = lambda h, i: int(h[1 + 2 * i:3 + 2 * i], 16)
    return "#" + "".join(f"{round(ch(fg, i) * a + ch(bg, i) * (1 - a)):02x}" for i in range(3))


def build(yaml):
    text = yaml.read_text()
    name = yaml.stem
    pal = dict(re.findall(r'^(base0[0-9A-F]):\s*"#?([0-9a-fA-F]{6})"', text, re.M))
    assert len(pal) == 16, f"expected 16 colors in {yaml.name}, found {len(pal)}"
    pal = {k: v.lower() for k, v in pal.items()}
    c = {k: "#" + v for k, v in pal.items()}
    b = lambda n: c[f"base{n}"]

    # Terminal ANSI mapping. Note: ANSI "yellow" is sage (0A) and "magenta" is the real yellow (0E).
    # Shell configs pick colors by ANSI name, so zsh/pwsh use "magenta" for commands to get yellow.
    ansi = [b("00"), b("08"), b("0B"), b("0A"), b("0D"), b("0E"), b("0C"), b("07")]
    brights = [b("04")] + ansi[1:]
    fg, bg, sel = b("07"), b("00"), b("02")

    def nvim():
        rows = [list(c)[i:i + 4] for i in range(0, 16, 4)]
        body = "\n".join("  " + " ".join(f'{k} = "{c[k]}",' for k in r) for r in rows)
        blends = []
        for k, zkey in BLEND.items():
            slot, a = zed_color(zkey)
            blends.append(f'    {k} = "{mix(c[slot], bg, a)}",')
        return f"return {{\n{body}\n  -- Zed's alpha colors, flattened over base00\n  blend = {{\n" + "\n".join(blends) + "\n  },\n}\n"

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
        out = ZED_TPL.replace("{{Name}}", name.capitalize())
        out = re.sub(r"\{\{(base0[0-9A-F])\}\}", lambda m: pal[m.group(1)], out)
        left = re.findall(r"\{\{[^}]*\}\}", out)
        assert not left, f"unknown tokens in zed template: {left}"
        return out

    return name, {
        f"nvim/lua/palettes/{name}.lua": nvim,
        f"wezterm/colors/{name}.toml": wezterm,
        f"ghostty/themes/{name}": ghostty,
        f"zed/themes/{name}.json": zed,
    }


check = "--check" in sys.argv
stale = []
for yaml in sorted(THEME.glob("*.yaml")):
    name, targets = build(yaml)
    theme_stale = []
    for rel, gen in targets.items():
        path, new = ROOT / rel, gen()
        if path.exists() and path.read_text() == new:
            continue
        theme_stale.append(rel)
        if not check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(new)
            print("wrote", rel)
    # JetBrains reads the nvim palette we just wrote. Only rebuild when the palette changed
    # (or its plugin is missing), since the plugin zip is binary and would churn on every run.
    jb_missing = not (ROOT / f"jetbrains/{name}/{name}-plugin.zip").exists()
    if jb_missing:
        theme_stale.append(f"jetbrains/{name}/")
    if not check and (f"nvim/lua/palettes/{name}.lua" in theme_stale or jb_missing or "--jetbrains" in sys.argv):
        subprocess.run([sys.executable, str(ROOT / "jetbrains/build.py"), name], check=True, stdout=subprocess.DEVNULL)
        print(f"rebuilt jetbrains/{name}/")
    stale += theme_stale

if check:
    if stale:
        print("out of date:", *stale, sep="\n  ")
        sys.exit(1)
    print("all themes up to date")
elif not stale:
    print("nothing changed")
