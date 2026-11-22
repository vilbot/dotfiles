#!/usr/bin/env python3
"""None's colour theme: any themes/<name>.yaml here or in ~/.config/none/themes/ (the 16 slots
of gruver16.yaml, plus `variant: light` for a light one), switched live, everywhere at once.

    theme.py list         the themes, one name per line
    theme.py themes       every theme with its colours, as JSON (the Settings app's Appearance page)
    theme.py get          the current one
    theme.py set NAME     switch to it
    theme.py ensure       write the files a new terminal needs if they're missing (tty/term)
    theme.py build        write None's own gruver16 files again, after editing themes/gruver16.yaml:
                          foot-colors.ini, colors.lua, shell/Colors.qml (settings/ links to it)
    theme.py build --check   exit 1 if any of them is out of date (writes nothing)

What a switch changes, while everything keeps running:
  - ~/.local/state/none/theme.json: the shell (tty/shell/Colors.qml) reads it again when it
    changes; an editor can read it too ($NONE_THEME)
  - ~/.local/state/none/foot-colors.ini: what new terminals start with (tty/foot.ini includes it)
  - ~/.local/state/none/hyprlock-colors.conf: the lock's colours (tty/hyprlock.conf, next lock)
  - every open None terminal: its colours by escape codes (OSC 4/10/11/12/17/19) written to its
    tty, so the shell, yazi, fzf and everything else using the terminal's colours changes at once
  - every running nvim: told the theme changed (`doautocmd User NoneTheme`, through its RPC socket)
  - Hyprland's border and background colours
  - light or dark for GTK, Qt and Chrome (tty/appearance.sh), when the variant changes
gruver16 until one is picked.
"""
import json, os, pathlib, re, socket, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
CONFIG = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "none"
THEMES = [HERE / "themes", CONFIG / "themes"]   # None's own, then yours (yours win on a shared name)
STATE = pathlib.Path(os.environ.get("XDG_STATE_HOME") or pathlib.Path.home() / ".local/state") / "none"
JSON, FOOT = STATE / "theme.json", STATE / "foot-colors.ini"
HYPRLOCK = STATE / "hyprlock-colors.conf"
APPEARANCE = HERE / "appearance.sh"
SLOTS = [f"base0{i:X}" for i in range(16)]


def files():
    return {p.stem: p for d in THEMES for p in sorted(d.glob("*.yaml"))}


def names():
    return sorted(files())


def load_file(path):
    text = path.read_text()
    pal = {k: "#" + v.lower() for k, v in re.findall(r'^(base0[0-9A-F]):\s*"([0-9a-fA-F]{6})"', text, re.M)}
    missing = [s for s in SLOTS if s not in pal]
    if missing:
        raise SystemExit(f"{path}: missing {', '.join(missing)}")
    return pal


def load(name):
    path = files()[name]
    text, pal = path.read_text(), load_file(path)
    variant = re.search(r'^variant:\s*"?(light|dark)"?', text, re.M)
    return {"name": name, "variant": variant.group(1) if variant else "dark", **pal}


def current():
    try:
        return json.loads(JSON.read_text())
    except (OSError, ValueError):
        return load("gruver16")


# ---- the terminal's colours ---------------------------------------------------------------------
# ANSI "yellow" is sage (0A), "magenta" the real yellow (0E); bright black is the muted grey.
def ansi(t):
    regular = [t[s] for s in ("base00", "base08", "base0B", "base0A", "base0D", "base0E", "base0C", "base07")]
    return regular + [t["base04"]] + regular[1:]


def foot_ini(t, header=None):
    h = lambda x: x.lstrip("#")
    lines = [header or f"# None's current theme ({t['name']}), written by tty/theme.py; tty/foot.ini includes it",
             "[colors-dark]", f"background={h(t['base00'])}", f"foreground={h(t['base07'])}",
             f"cursor={h(t['base00'])} {h(t['base07'])}",
             f"selection-background={h(t['base02'])}", f"selection-foreground={h(t['base07'])}"]
    lines += [f"{'regular' if i < 8 else 'bright'}{i % 8}={h(x)}" for i, x in enumerate(ansi(t))]
    return "\n".join(lines) + "\n"


def hyprlock_conf(t):
    """the lock's colours (tty/hyprlock.conf sources it): $baseXX = rgb(...) for its colour
    options, $baseXXhex = the bare hex for Pango markup ("##$base08hex" in its texts)"""
    lines = [f"# None's current theme ({t['name']}), written by tty/theme.py; tty/hyprlock.conf sources it"]
    lines += [f"${s} = rgb({t[s][1:]})\n${s}hex = {t[s][1:]}" for s in SLOTS]
    return "\n".join(lines) + "\n"


def osc(t):
    st = "\x1b\\"
    seq = "".join(f"\x1b]4;{i};{x}{st}" for i, x in enumerate(ansi(t)))
    for code, slot in ((10, "base07"), (11, "base00"), (12, "base07"), (17, "base02"), (19, "base07")):
        seq += f"\x1b]{code};{t[slot]}{st}"
    return seq.encode()


def terminals():
    """the ttys of None's open terminals (foot started with tty/foot.ini)"""
    ini = str(HERE / "foot.ini")
    ttys = set()
    for proc in pathlib.Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            argv = (proc / "cmdline").read_bytes().split(b"\0")
            if not argv[0].endswith(b"foot") or ini.encode() not in argv:
                continue
            for child in (proc / "task" / proc.name / "children").read_text().split():
                tty = os.readlink(f"/proc/{child}/fd/0")
                if tty.startswith("/dev/pts/"):
                    ttys.add(tty)
        except OSError:
            continue
    return ttys


def recolour_terminals(t):
    data = osc(t)
    for tty in terminals():
        try:
            fd = os.open(tty, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
            try:
                os.write(fd, data)
            finally:
                os.close(fd)
        except OSError:
            pass


# ---- nvim: a msgpack-rpc notification, ["nvim_command", [cmd]], to every nvim's socket ----------
def mp_str(s):
    b = s.encode()
    n = len(b)
    head = bytes([0xa0 | n]) if n < 32 else bytes([0xd9, n]) if n < 256 else bytes([0xda]) + n.to_bytes(2, "big")
    return head + b


# None doesn't know your nvim config: it only says the theme changed. A config that follows it
# reads $NONE_THEME (JSON: base00..base0F as "#rrggbb", "variant" = "dark" | "light") and has
#   autocmd User NoneTheme  <load the colorscheme again>
NVIM_RELOAD = "silent! doautocmd User NoneTheme"


def reload_nvims():
    msg = bytes([0x93, 0x02]) + mp_str("nvim_command") + bytes([0x91]) + mp_str(NVIM_RELOAD)
    run = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    for sock in run.glob("nvim.*.0"):
        try:
            with socket.socket(socket.AF_UNIX) as s:
                s.settimeout(0.2)
                s.connect(str(sock))
                s.sendall(msg)
        except OSError:
            pass   # an nvim that has gone: its socket stays behind


# ---- Hyprland and the rest of the desktop ------------------------------------------------------
def hyprland(t):
    if not os.environ.get("NONE_THEME"):   # only None's own Hyprland (tty/hyprland.lua sets it)
        return
    rgb = lambda s: f'"rgba({t[s][1:]}ff)"'
    lua = (f"hl.config({{ general = {{ col = {{ active_border = {rgb('base0D')}, inactive_border = {rgb('base02')} }} }}, "
           f"misc = {{ background_color = {rgb('base00')} }} }})")
    subprocess.Popen(["hyprctl", "eval", lua], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def light_or_dark(t):
    """GTK, Qt, Chrome and websites: light or dark. Slow (KDE's colour scheme), so in the
    background, one at a time, each for the theme current when its turn comes (switching fast
    through the list ends on the right one)"""
    if not APPEARANCE.exists():
        return
    worker = (f'exec 9>"{STATE}/appearance.lock"; flock 9; '
              f'v=$(sed -n \'s/^ *"variant": "\\(.*\\)",*$/\\1/p\' "{JSON}"); '
              f'[ "$("{APPEARANCE}" get)" = "$v" ] || "{APPEARANCE}" "$v"')
    subprocess.Popen(["sh", "-c", worker], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def write(t):
    STATE.mkdir(parents=True, exist_ok=True)
    FOOT.write_text(foot_ini(t))
    HYPRLOCK.write_text(hyprlock_conf(t))
    JSON.write_text(json.dumps(t, indent=1) + "\n")


# ---- None's own files, generated from themes/gruver16.yaml (theme.py build) -------------------
GENERATED = "generated by tty/theme.py build from tty/themes/gruver16.yaml; do not edit"


def colors_lua(t):
    """hex without '#': require("colors").base0D (hyprland.lua before a theme is picked, the
    login screen, the boot screens)"""
    body = "\n".join(f'  {s} = "{t[s][1:]}",' for s in SLOTS)
    return f"-- {GENERATED}\nreturn {{\n{body}\n}}\n"


def colors_qml(t):
    """the shell's and the Settings app's colours: the theme picked (theme.json, read again when
    it changes), gruver16 until then"""
    body = "\n".join(f'    readonly property color {s}: theme.{s} ?? "{t[s]}"' for s in SLOTS)
    return (f"// {GENERATED}\n"
            "// None's current theme (~/.local/state/none/theme.json, written by tty/theme.py), read again\n"
            "// when it changes, so everything drawn with these changes with it; gruver16 until one is picked.\n"
            "pragma Singleton\nimport QtQuick\nimport Quickshell\nimport Quickshell.Io\n\nSingleton {\n"
            "    id: root\n"
            "    property var theme: ({})\n"
            "    readonly property bool light: theme.variant === \"light\"\n"
            "    FileView {\n"
            "        path: (Quickshell.env(\"XDG_STATE_HOME\") || Quickshell.env(\"HOME\") + \"/.local/state\") + \"/none/theme.json\"\n"
            "        watchChanges: true\n"
            "        onFileChanged: reload()\n"
            "        // a file caught half-written doesn't parse: the last good one stays\n"
            "        onLoaded: { try { const t = JSON.parse(text()); if (t.base00) root.theme = t } catch (e) {} }\n"
            "    }\n"
            f"{body}\n}}\n")


def build(check):
    t = {"name": "gruver16", "variant": "dark", **load_file(HERE / "themes" / "gruver16.yaml")}
    targets = {"foot-colors.ini": foot_ini(t, "# " + GENERATED), "colors.lua": colors_lua(t),
               "shell/Colors.qml": colors_qml(t)}
    stale = [rel for rel, new in targets.items()
             if not (HERE / rel).exists() or (HERE / rel).read_text() != new]
    if check:
        if stale:
            print("out of date (theme.py build):", *stale, sep="\n  ")
            sys.exit(1)
        return
    for rel in stale:
        (HERE / rel).write_text(targets[rel])
        print("wrote", rel)
    if not stale:
        print("nothing changed")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "list":
        print("\n".join(names()))
    elif cmd == "themes":
        print(json.dumps([load(n) for n in names()]))
    elif cmd == "get":
        print(current()["name"])
    elif cmd == "ensure":
        if not (FOOT.exists() and JSON.exists() and HYPRLOCK.exists()):
            write(current())
    elif cmd == "build":
        build("--check" in sys.argv)
    elif cmd == "set" and len(sys.argv) == 3:
        if sys.argv[2] not in names():
            raise SystemExit(f"no theme {sys.argv[2]} (there are: {', '.join(names())})")
        t, before = load(sys.argv[2]), current()
        write(t)   # first: the shell reads it, and terminals opened from now on
        recolour_terminals(t)
        reload_nvims()
        hyprland(t)
        if t["variant"] != before["variant"]:
            light_or_dark(t)
    else:
        print(__doc__.split("\n\n")[1])
        sys.exit(2)


if __name__ == "__main__":
    main()
