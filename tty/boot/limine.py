#!/usr/bin/env python3
"""Limine's menu in gruver16: sets the colour options among limine.conf's global options (the
lines before the first entry) and drops any wallpaper, so it's None's plain gray. Entries are
left alone. Colours: tty/foot-colors.ini (the terminal palette) and tty/colors.lua.

    limine.py FILE        rewrite FILE (tty/boot.sh: /boot/limine.conf, after a backup)
    limine.py FILE --show print what FILE would become, change nothing
    limine.py FILE --remove   take the gruver16 options out again (the wallpaper stays gone)
"""
import pathlib, re, sys

TTY = pathlib.Path(__file__).resolve().parents[1]
pal = dict(re.findall(r'(base0[0-9A-F]) = "([0-9a-f]{6})"', (TTY / "colors.lua").read_text()))
foot = dict(re.findall(r"^(regular\d|bright\d)=([0-9a-fA-F]{6})$", (TTY / "foot-colors.ini").read_text(), re.M))
assert len(pal) == 16 and len(foot) == 16, "colour sources incomplete"

OPTIONS = {
    "term_palette": ";".join(foot[f"regular{i}"] for i in range(8)),
    "term_palette_bright": ";".join(foot[f"bright{i}"] for i in range(8)),
    "term_background": "00" + pal["base00"],     # TTRRGGBB, 00 = opaque
    "term_foreground": pal["base06"],
    "term_background_bright": pal["base02"],
    "term_foreground_bright": pal["base07"],
    "backdrop": pal["base00"],
    "interface_branding_colour": pal["base0E"],
    "interface_help_colour": pal["base0D"],
}
# also ours: these go (a wallpaper would cover the gray), and the colour spellings Limine accepts
DROP = {"wallpaper", "wallpaper_style", "interface_branding_color", "interface_help_color"}
MARK = "# gruver16 (None: boot/limine.py)"
OLD_MARKS = {"# gruver16 (" + "dot" + "files: tty/boot/limine.py)"}   # what earlier versions wrote


def themed(text, add=True):
    lines = text.splitlines()
    first_entry = next((i for i, l in enumerate(lines) if l.lstrip().startswith("/")), len(lines))
    head, rest = lines[:first_entry], lines[first_entry:]
    keep = [l for l in head
            if l.strip() != MARK and l.strip() not in OLD_MARKS and l.split(":", 1)[0].strip().lower() not in OPTIONS.keys() | DROP]
    block = [MARK] + [f"{k}: {v}" for k, v in OPTIONS.items()] if add else []
    return "\n".join(block + keep + rest) + "\n"


if __name__ == "__main__":
    path = pathlib.Path(sys.argv[1])
    new = themed(path.read_text(), add="--remove" not in sys.argv)
    if "--show" in sys.argv:
        print(new, end="")
    else:
        path.write_text(new)
