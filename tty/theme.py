#!/usr/bin/env python3
"""None's colour theme: any theme/<name>.yaml (the 16 slots of gruver16.yaml, plus
`variant: light` for a light one), switched live, everywhere at once.

    theme.py list         the themes, one name per line
    theme.py themes       every theme with its colours, as JSON (the Settings app's Appearance page)
    theme.py get          the current one
    theme.py set NAME     switch to it
    theme.py ensure       write the files a new terminal needs if they're missing (tty/term)

What a switch changes, while everything keeps running:
  - ~/.local/state/none/theme.json: the shell (tty/shell/Colors.qml) reads it again when it
    changes; nvim reads it at start ($NONE_THEME, nvim/lua/palettes/current.lua)
  - ~/.local/state/none/foot-colors.ini: what new terminals start with (tty/foot.ini includes it)
  - every open None terminal: its colours by escape codes (OSC 4/10/11/12/17/19) written to its
    tty, so the shell, yazi, fzf and everything else using the terminal's colours changes at once
  - every running nvim: told to load its colorscheme again (through its RPC socket)
  - Hyprland's border and background colours
  - light or dark for GTK, Qt and Chrome (hypr/appearance.sh), when the variant changes
gruver16 until one is picked. The other desktops keep gruver16 (theme/build.py).
"""
import json, os, pathlib, re, socket, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
THEMES = HERE.parent / "theme"
STATE = pathlib.Path(os.environ.get("XDG_STATE_HOME") or pathlib.Path.home() / ".local/state") / "none"
JSON, FOOT = STATE / "theme.json", STATE / "foot-colors.ini"
APPEARANCE = HERE.parent / "hypr" / "appearance.sh"
SLOTS = [f"base0{i:X}" for i in range(16)]


def names():
    return sorted(p.stem for p in THEMES.glob("*.yaml"))


def load(name):
    text = (THEMES / f"{name}.yaml").read_text()
    pal = {k: "#" + v.lower() for k, v in re.findall(r'^(base0[0-9A-F]):\s*"([0-9a-fA-F]{6})"', text, re.M)}
    missing = [s for s in SLOTS if s not in pal]
    if missing:
        raise SystemExit(f"theme/{name}.yaml: missing {', '.join(missing)}")
    variant = re.search(r'^variant:\s*"?(light|dark)"?', text, re.M)
    return {"name": name, "variant": variant.group(1) if variant else "dark", **pal}


def current():
    try:
        return json.loads(JSON.read_text())
    except (OSError, ValueError):
        return load("gruver16")


# ---- the terminal's colours: the same mapping as theme/build.py ------------------------------
# ANSI "yellow" is sage (0A), "magenta" the real yellow (0E); bright black is the muted grey.
def ansi(t):
    regular = [t[s] for s in ("base00", "base08", "base0B", "base0A", "base0D", "base0E", "base0C", "base07")]
    return regular + [t["base04"]] + regular[1:]


def foot_ini(t):
    h = lambda x: x.lstrip("#")
    lines = [f"# None's current theme ({t['name']}), written by tty/theme.py; tty/foot.ini includes it",
             "[colors-dark]", f"background={h(t['base00'])}", f"foreground={h(t['base07'])}",
             f"cursor={h(t['base00'])} {h(t['base07'])}",
             f"selection-background={h(t['base02'])}", f"selection-foreground={h(t['base07'])}"]
    lines += [f"{'regular' if i < 8 else 'bright'}{i % 8}={h(x)}" for i, x in enumerate(ansi(t))]
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


NVIM_RELOAD = ('lua if vim.g.colors_name == "custom" then package.loaded["palettes.current"] = nil; '
               'vim.cmd.colorscheme("custom") end')


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
    JSON.write_text(json.dumps(t, indent=1) + "\n")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "list":
        print("\n".join(names()))
    elif cmd == "themes":
        print(json.dumps([load(n) for n in names()]))
    elif cmd == "get":
        print(current()["name"])
    elif cmd == "ensure":
        if not (FOOT.exists() and JSON.exists()):
            write(current())
    elif cmd == "set" and len(sys.argv) == 3:
        if sys.argv[2] not in names():
            raise SystemExit(f"no theme {sys.argv[2]} (theme/*.yaml: {', '.join(names())})")
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
