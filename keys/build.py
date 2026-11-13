#!/usr/bin/env python3
"""Generate per-platform keybinds from keys/keymap.toml (needs Python 3.11+ for tomllib).

    python3 keys/build.py           # write all targets
    python3 keys/build.py --check   # exit 1 if any target is out of date (writes nothing)
    python3 keys/build.py --apply   # write targets, then apply the KDE one with kwriteconfig6

Generated files (do NOT hand-edit, edit keymap.toml instead):
    keys/generated/kde.tsv          <- KDE shortcut values; --apply writes them into ~/.config
    hypr/binds.lua                  <- Hyprland binds; hyprland.lua does require("binds")(programs)
    quickshell/KeybindsData.qml     <- rows for the Opt+? cheat sheet (labels in SHEET below)

KDE rewrites kglobalshortcutsrc itself, so it can't be symlinked. --apply only touches the
entries listed in kde.tsv and keeps each entry's default/friendly name. Log out and back in
afterwards: KDE only reads the file at login.

Each platform has an action table below (KDE_ACTIONS, HYPR_ACTIONS). An action a platform
doesn't map is skipped there; an action no platform maps is an error.
"""
import json, pathlib, re, shutil, subprocess, sys, tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
cfg = tomllib.loads((ROOT / "keys/keymap.toml").read_text())
N = cfg["desktops"]
DIRS = {"left": "h", "down": "j", "up": "k", "right": "l"}

# ---- parse keymap -------------------------------------------------------------------------
MODS = ("cmd", "opt", "ctrl", "shift")


def parse(combo):
    """'opt+shift+w' -> (frozenset({'opt','shift'}), 'w')"""
    *mods, key = combo.lower().split("+")
    bad = [m for m in mods if m not in MODS]
    assert not bad, f"unknown modifier {bad} in {combo!r} (use {', '.join(MODS)})"
    return frozenset(mods), key


def expand(action):
    """Yield (action, key-substitution) pairs for {n} / {dir} placeholders."""
    if "{n}" in action:
        for n in range(1, N + 1):
            yield action.replace("{n}", str(n)), lambda s, n=n: s.replace("{n}", str(n))
    elif "{dir}" in action:
        for d, k in DIRS.items():
            yield action.replace("{dir}", d), lambda s, k=k: s.replace("{dir}", k)
    else:
        yield action, lambda s: s


binds = {}  # action -> [(mods, key)]
for action, keys in cfg["binds"].items():
    keys = [keys] if isinstance(keys, str) else keys
    for name, sub in expand(action):
        binds[name] = [parse(sub(k)) for k in keys]

seen = {}
for action, combos in binds.items():
    for c in combos:
        assert c not in seen, f"{'+'.join(sorted(c[0]))}+{c[1]} bound to both {seen[c]} and {action}"
        seen[c] = action

# What Linux desktops receive after Toshy (normal apps, Mac keyboard): physical -> sent.
TOSHY_MOD = {"ctrl": "super", "cmd": "ctrl", "opt": "alt", "shift": "shift"}  # dict order = output order
# Combos Toshy swallows and replaces with a desktop-specific shortcut, per desktop.
TOSHY_SPECIAL = {
    "kde":  {(frozenset({"cmd"}), "space"): "Alt+F2",      # KRunner's first shortcut
             (frozenset({"cmd"}), "q"): "Alt+F4"},         # toshy/slices/user_apps.py
    # Toshy's default is Super+D, but physical Ctrl+D sends that too (e.g. vim's Ctrl+D in Zed);
    # toshy/slices/user_apps.py makes Cmd+Space send Super+F13 on Hyprland instead. F13's keysym
    # is XF86Tools on Linux, so bind the raw keycode (evdev 183 + 8).
    "hypr": {(frozenset({"cmd"}), "space"): "SUPER + code:191",
             (frozenset({"cmd"}), "q"): "ALT + F4"},       # toshy/slices/user_apps.py
}

# ---- KDE ----------------------------------------------------------------------------------
KDE_MOD = {"super": "Meta", "ctrl": "Ctrl", "alt": "Alt", "shift": "Shift"}
KDE_KEY = {"space": "Space", "tab": "Tab", "enter": "Return", "escape": "Esc", "left": "Left",
           "right": "Right", "up": "Up", "down": "Down", "backspace": "Backspace"}


def kde_combo(c):
    if c in TOSHY_SPECIAL["kde"]:
        return TOSHY_SPECIAL["kde"][c]
    mods, key = c
    key = KDE_KEY.get(key) or (key.upper() if re.fullmatch(r"[a-z]|f\d+", key) else key)
    return "+".join([KDE_MOD[TOSHY_MOD[m]] for m in TOSHY_MOD if m in mods] + [key])


SC = "kglobalshortcutsrc"
KDE_ACTIONS = {  # action -> (file, groups, key, extra fixed keys)
    **{f"desktop.goto.{n}": (SC, ["kwin"], f"Switch to Desktop {n}", []) for n in range(1, N + 1)},
    **{f"desktop.move.{n}": (SC, ["kwin"], f"Window to Desktop {n}", []) for n in range(1, N + 1)},
    "desktop.prev": (SC, ["kwin"], "Switch to Previous Desktop", []),
    "desktop.next": (SC, ["kwin"], "Switch to Next Desktop", []),
    "desktop.move.prev": (SC, ["kwin"], "Window to Previous Desktop", []),
    "desktop.move.next": (SC, ["kwin"], "Window to Next Desktop", []),
    "layout.next":  (SC, ["KDE Keyboard Layout Switcher"], "Switch to Next Keyboard Layout", []),
    "launcher":     (SC, ["services", "org.kde.krunner.desktop"], "_launch", ["Search"]),
    "window.close": (SC, ["kwin"], "Window Close", []),
}


def kde():
    rows = [("kwinrc", "Desktops", "Number", str(N))]
    for action, (file, groups, key, extra) in KDE_ACTIONS.items():
        keys = [kde_combo(c) for c in binds.get(action, [])] + extra
        rows.append((file, "][".join(groups), key, "\\t".join(keys) or "none"))
    head = "# generated by keys/build.py from keys/keymap.toml; do not edit\n# file\tgroup\tkey\tshortcut\n"
    return head + "".join("\t".join(r) + "\n" for r in rows)


def apply_kde(tsv):
    if not shutil.which("kwriteconfig6"):
        sys.exit("kwriteconfig6 not found; is this a KDE Plasma 6 session?")
    rd = lambda f, g, k: subprocess.run(["kreadconfig6", "--file", f, *sum([["--group", x] for x in g], []),
                                         "--key", k], capture_output=True, text=True).stdout.rstrip("\n")
    for line in tsv.splitlines():
        if line.startswith("#"):
            continue
        file, group, key, value = line.split("\t")
        groups = group.split("][")
        value = value.replace("\\t", "\t")
        if file == SC and groups[0] != "services":  # kwin-style "active,default,friendly name"
            old = rd(file, groups, key).split(",", 2)
            value = ",".join([value, *(old[1:] if len(old) == 3 else ["none", key])])
        same = lambda a, b: [sorted(x.split(",", 1)[0].split("\t")) + x.split(",", 1)[1:] for x in (a, b)]
        cur, new = same(rd(file, groups, key), value)
        if cur != new:  # KDE reorders multi-key shortcuts itself; ignore order
            subprocess.run(["kwriteconfig6", "--file", file, *sum([["--group", x] for x in groups], []),
                            "--key", key, value], check=True)
            print(f"set     {file} [{group}] {key}")
    print("done; log out and back in for KDE to pick up shortcut changes")


# ---- Hyprland -----------------------------------------------------------------------------
HYPR_KEY = {"enter": "Return", "escape": "Escape", "space": "space", "tab": "Tab", "backspace": "BackSpace",
            "slash": "slash"}


def hypr_combo(c):
    if c in TOSHY_SPECIAL["hypr"]:
        return TOSHY_SPECIAL["hypr"][c]
    mods, key = c
    key = HYPR_KEY.get(key) or (key.upper() if re.fullmatch(r"[a-z]|f\d+", key) else key)
    return " + ".join([TOSHY_MOD[m].upper() for m in TOSHY_MOD if m in mods] + [key])


# Desktops wrap around 1..N like KDE (Hyprland's own relative workspaces don't stop at N).
_step = lambda d, dsp="hl.dsp.focus({{ workspace = {} }})": (
    f"function() local id = (hl.get_active_workspace() or {{}}).id or 1; "
    f"hl.dispatch({dsp.format(f'(id - 1 {d}) % {N} + 1')}) end")
# Moving a window doesn't switch desktop (like KDE's "Window to Desktop N").
_move = "hl.dsp.window.move({{ workspace = {}, follow = false }})"
HYPR_ACTIONS = {  # action -> Lua dispatcher (P = programs table from hyprland.lua)
    **{f"desktop.goto.{n}": f"hl.dsp.focus({{ workspace = {n} }})" for n in range(1, N + 1)},
    **{f"desktop.move.{n}": _move.format(n) for n in range(1, N + 1)},
    "desktop.prev": _step("- 1"),
    "desktop.next": _step("+ 1"),
    "desktop.move.prev": _step("- 1", _move),
    "desktop.move.next": _step("+ 1", _move),
    "layout.next": 'hl.dsp.exec_cmd("hyprctl switchxkblayout all next")',
    "launcher": "hl.dsp.exec_cmd(P.launcher)",
    "launcher.alt": "hl.dsp.exec_cmd(P.launcher_alt)",
    "terminal": "hl.dsp.exec_cmd(P.terminal)",
    **{f"window.focus.{d}": f'hl.dsp.focus({{ direction = "{d}" }})' for d in DIRS},
    **{f"window.move.{d}": f'hl.dsp.window.move({{ direction = "{d}" }})' for d in DIRS},
    "window.close": "hl.dsp.window.close()",
    "window.fullscreen": 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })',
    "window.float": 'hl.dsp.window.float({ action = "toggle" })',
    "session.exit": "hl.dsp.exit()",
    "help.keys": 'hl.dsp.exec_cmd("qs ipc call keybinds toggle")',
}


def hypr():
    lines = ["-- generated by keys/build.py from keys/keymap.toml; do not edit",
             "-- usage in hyprland.lua: require(\"binds\")({ terminal = ..., launcher = ..., launcher_alt = ... })",
             "return function(P)"]
    for action, combos in binds.items():
        if action in HYPR_ACTIONS:
            lines += [f'  hl.bind("{hypr_combo(c)}", {HYPR_ACTIONS[action]}) -- {action}' for c in combos]
    return "\n".join(lines + ["end"]) + "\n"


# ---- cheat sheet (Quickshell, Hyprland) ---------------------------------------------------
# Rows shown by the Opt+? overlay (quickshell/Keybinds.qml). Keyed by the action as written in
# keymap.toml (placeholders unexpanded), so {n}/{dir} actions get one row each. Order = display.
SHEET = {
    "Desktops": {
        "desktop.goto.{n}":  "Go to desktop",
        "desktop.prev":      "Previous desktop",
        "desktop.next":      "Next desktop",
        "desktop.move.{n}":  "Send window to desktop",
        "desktop.move.prev": "Send window to previous desktop",
        "desktop.move.next": "Send window to next desktop",
    },
    "Windows": {
        "window.focus.{dir}": "Focus window",
        "window.move.{dir}":  "Move window",
        "window.close":       "Close window",
        "window.fullscreen":  "Fullscreen",
        "window.float":       "Floating",
    },
    "Launch & type": {
        "launcher":     "Launcher",
        "launcher.alt": "Other launcher",
        "terminal":     "Terminal",
        "layout.next":  "Switch keyboard layout",
    },
    "Session": {
        "help.keys":    "This sheet",
        "session.exit": "Log out",
    },
}
# Binds that live in hyprland.lua, not keymap.toml (mouse).
SHEET_EXTRA = {"Windows": [("Move window with mouse", ["⌥ drag"]),
                           ("Resize window with mouse", ["⌥ right-drag"])]}

MAC_MOD = {"ctrl": "⌃", "opt": "⌥", "shift": "⇧", "cmd": "⌘"}   # Apple's order
MAC_KEY = {"space": "Space", "enter": "↩", "escape": "Esc", "tab": "⇥", "backspace": "⌫",
           "left": "←", "right": "→", "up": "↑", "down": "↓", "slash": "/"}
SHIFTED = {"slash": "?"}   # shown as the shifted character, like macOS menus do


def mac_label(combo):
    """'opt+shift+{n}' -> '⌥ ⇧ 1–5', 'opt+shift+slash' -> '⌥ ?', 'opt+{dir}' -> '⌥ H J K L'"""
    *mods, key = combo.lower().split("+")
    if "shift" in mods and key in SHIFTED:
        mods.remove("shift"); key = SHIFTED[key]
    elif key == "{n}":
        key = f"1–{N}"
    elif key == "{dir}":
        key = " ".join(DIRS.values()).upper()
    else:
        key = MAC_KEY.get(key, key.upper())
    return " ".join([MAC_MOD[m] for m in MAC_MOD if m in mods] + [key])


def sheet():
    groups = []
    for title, rows in SHEET.items():
        out = []
        for action, label in rows.items():
            keys = cfg["binds"].get(action, [])
            keys = [keys] if isinstance(keys, str) else keys
            if keys:
                out.append({"label": label, "keys": [mac_label(k) for k in keys]})
        out += [{"label": l, "keys": k} for l, k in SHEET_EXTRA.get(title, [])]
        groups.append({"title": title, "rows": out})
    missing = set(cfg["binds"]) - {a for rows in SHEET.values() for a in rows}
    assert not missing, f"add {sorted(missing)} to SHEET in keys/build.py (cheat sheet labels)"
    body = json.dumps(groups, indent=4, ensure_ascii=False).replace("\n", "\n    ")
    return ("// generated by keys/build.py from keys/keymap.toml; do not edit\n"
            "pragma Singleton\nimport QtQuick\nimport Quickshell\n\nSingleton {\n"
            f"    readonly property var groups: {body}\n}}\n")


unmapped = set(binds) - set(KDE_ACTIONS) - set(HYPR_ACTIONS)
assert not unmapped, f"no platform maps {sorted(unmapped)}: add them to KDE_ACTIONS / HYPR_ACTIONS"

# ---- write --------------------------------------------------------------------------------
targets = {"keys/generated/kde.tsv": kde, "hypr/binds.lua": hypr,
           "quickshell/KeybindsData.qml": sheet}

check = "--check" in sys.argv
stale = []
for rel, gen in targets.items():
    path, new = ROOT / rel, gen()
    if path.exists() and path.read_text() == new:
        continue
    stale.append(rel)
    if not check:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(new)
        print("wrote", rel)

if check:
    if stale:
        print("out of date:", *stale, sep="\n  ")
        sys.exit(1)
elif "--apply" in sys.argv:
    apply_kde((ROOT / "keys/generated/kde.tsv").read_text())
