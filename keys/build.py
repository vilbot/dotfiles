#!/usr/bin/env python3
"""Generate per-platform keybinds from keys/keymap.toml (needs Python 3.11+ for tomllib).

    python3 keys/build.py           # write all targets
    python3 keys/build.py --check   # exit 1 if any target is out of date (writes nothing)
    python3 keys/build.py --apply   # write targets, then apply the KDE one with kwriteconfig6
    python3 keys/build.py --set '{"window.pin": {"hypr": ["opt+p"], "kde": null}}' [--apply]
        # change binds in keymap.toml (comments kept), then build; puts the file back if the
        # build fails. Used by the settings window's Shortcuts page. kde: null = same as Hyprland.

Generated files (do NOT hand-edit, edit keymap.toml instead):
    keys/generated/kde.tsv          <- KDE shortcut values; --apply writes them into ~/.config
    hypr/binds.lua                  <- Hyprland binds; hyprland.lua does require("binds")(programs)
    quickshell/keymap.json          <- every action with its keys and label, for the Opt+? sheet
                                       (quickshell/Keybinds.qml) and the settings window's
                                       Shortcuts page (quickshell/ShortcutsPage.qml)

KDE rewrites kglobalshortcutsrc itself, so it can't be symlinked. --apply only touches the
entries listed in kde.tsv and keeps each entry's default/friendly name. Log out and back in
afterwards: KDE only reads the file at login.

keymap.toml lists every action HYPR_ACTIONS knows (unbound ones as []), so it's a complete
list of what can be bound. KDE_ACTIONS maps the actions that have a KDE equivalent.
"""
import json, pathlib, re, shutil, subprocess, sys, tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEYMAP = ROOT / "keys/keymap.toml"


# ---- --set: edit keymap.toml in place --------------------------------------------------------
def toml_keys(keys):
    keys = list(keys)
    return json.dumps(keys[0]) if len(keys) == 1 else "[" + ", ".join(json.dumps(k) for k in keys) + "]"


def set_binds(changes, apply):
    old = KEYMAP.read_text()
    lines = old.split("\n")
    for action, ch in changes.items():
        value = toml_keys(ch["hypr"])
        if ch.get("kde") is not None:
            value = f"{{ hypr = {value}, kde = {toml_keys(ch['kde'])} }}"
        pat = re.compile(r'^("' + re.escape(action) + r'"\s*=\s*)(.*?)(\s+#.*)?$')
        hits = [i for i, l in enumerate(lines) if pat.match(l)]
        if len(hits) != 1:
            sys.exit(f"{action} is not in keymap.toml")
        m = pat.match(lines[hits[0]])
        line = m.group(1) + value
        if m.group(3):   # keep the comment in its column
            col = len(m.group(1) + m.group(2)) + len(m.group(3)) - len(m.group(3).lstrip())
            line += " " * max(1, col - len(line)) + m.group(3).lstrip()
        lines[hits[0]] = line
    KEYMAP.write_text("\n".join(lines))
    r = subprocess.run([sys.executable, __file__] + (["--apply"] if apply else []), capture_output=True, text=True)
    if r.returncode:
        KEYMAP.write_text(old)
        subprocess.run([sys.executable, __file__], capture_output=True)   # regenerate from the old file
        err = (r.stderr.strip().splitlines() or ["build failed"])[-1]
        sys.exit(re.sub(r"^\w+Error: ", "", err))
    print(r.stdout, end="")
    sys.exit(0)


if "--set" in sys.argv:
    set_binds(json.loads(sys.argv[sys.argv.index("--set") + 1]), "--apply" in sys.argv)

cfg = tomllib.loads(KEYMAP.read_text())
N = cfg["desktops"]
DIRS = {"left": "h", "down": "j", "up": "k", "right": "l"}

# ---- parse keymap -------------------------------------------------------------------------
MODS = ("cmd", "opt", "ctrl", "shift")
KEYS = ({chr(c) for c in range(ord("a"), ord("z") + 1)} | {str(d) for d in range(10)} | {f"f{i}" for i in range(1, 25)}
        | {"space", "tab", "enter", "escape", "backspace", "delete", "left", "right", "up", "down", "home", "end",
           "pageup", "pagedown", "print", "grave", "minus", "equal", "period", "slash", "semicolon", "apostrophe",
           "bracketleft", "bracketright", "backslash"})


def parse(combo):
    """'opt+shift+w' -> (frozenset({'opt','shift'}), 'w')"""
    *mods, key = combo.lower().replace(" ", "").split("+")
    bad = [m for m in mods if m not in MODS]
    assert not bad, f"unknown modifier {'+'.join(bad)} in {combo} (use {', '.join(MODS)})"
    assert key in KEYS, f"unknown key {key!r} in {combo} (letters, digits, f1-f24 or {', '.join(sorted(k for k in KEYS if len(k) > 3 and not k.startswith('f')))})"
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


def key_list(v):
    return [v] if isinstance(v, str) else list(v)


# keymap.toml value: "key", ["key", ...], [] (unbound) or { hypr = ..., kde = ... } (kde: KDE's own
# keys; without it KDE uses the Hyprland keys)
src = {"hypr": {}, "kde": {}}    # action template -> [combo strings]
kde_own = set()                  # templates with their own KDE keys
for action, v in cfg["binds"].items():
    if isinstance(v, dict):
        assert set(v) <= {"hypr", "kde"}, f"{action}: only hypr and kde go in {{ }}"
        src["hypr"][action] = key_list(v.get("hypr", []))
        src["kde"][action] = key_list(v["kde"]) if "kde" in v else src["hypr"][action]
        kde_own |= {action} if "kde" in v else set()
    else:
        src["hypr"][action] = src["kde"][action] = key_list(v)
    for k in src["hypr"][action] + src["kde"][action]:
        for ph, word in (("{n}", "desktop number"), ("{dir}", "direction")):
            assert (ph in action) == (ph in k), \
                f"{action}: {'put' if ph in action else 'no'} {ph} ({word}) in the key {k}"

binds = {}   # platform -> action -> [(mods, key)]
for plat in src:
    binds[plat] = {name: [parse(sub(k)) for k in keys]
                   for action, keys in src[plat].items() for name, sub in expand(action)}

# What Linux desktops receive after Toshy (normal apps, Mac keyboard): physical -> sent.
TOSHY_MOD = {"ctrl": "super", "cmd": "ctrl", "opt": "alt", "shift": "shift"}  # dict order = output order
# Combos Toshy swallows and replaces with a desktop-specific shortcut, per desktop.
TOSHY_SPECIAL = {
    "kde":  {(frozenset({"cmd"}), "space"): "Alt+F2",      # KRunner's first shortcut
             (frozenset({"cmd"}), "q"): "Alt+F4",          # toshy/slices/user_apps.py
             # Toshy sends Opt+(Shift+)Tab as Super+F14 so it can't collide with Cmd+Tab (Alt+Tab)
             (frozenset({"opt"}), "tab"): "Meta+F14",
             (frozenset({"opt", "shift"}), "tab"): "Meta+Shift+F14",
             # Toshy sends Cmd+(Shift+)Tab as Alt+(Shift+)Tab, holding Alt while Cmd is held
             (frozenset({"cmd"}), "tab"): "Alt+Tab",
             (frozenset({"cmd", "shift"}), "tab"): "Alt+Shift+Tab",
             # and Cmd+(Shift+)` as Alt+(Shift+)`
             (frozenset({"cmd"}), "grave"): "Alt+`",
             (frozenset({"cmd", "shift"}), "grave"): "Alt+~"},
    # Toshy's default is Super+D, but physical Ctrl+D sends that too (e.g. vim's Ctrl+D in Zed);
    # toshy/slices/user_apps.py makes Cmd+Space send Super+F13 on Hyprland instead. F13's keysym
    # is XF86Tools on Linux, so bind the raw keycode (evdev 183 + 8).
    "hypr": {(frozenset({"cmd"}), "space"): "SUPER + code:191",
             (frozenset({"cmd"}), "q"): "ALT + F4",        # toshy/slices/user_apps.py
             # Opt+(Shift+)Tab arrive as Super+F14 (see kde above); F14 = evdev 184 + 8
             (frozenset({"opt"}), "tab"): "SUPER + code:192",
             (frozenset({"opt", "shift"}), "tab"): "SUPER + SHIFT + code:192",
             (frozenset({"cmd"}), "tab"): "ALT + Tab",
             (frozenset({"cmd", "shift"}), "tab"): "ALT + SHIFT + Tab",
             (frozenset({"cmd"}), "grave"): "ALT + grave",
             (frozenset({"cmd", "shift"}), "grave"): "ALT + SHIFT + grave",
             # the NuPhy's screenshot key sends Cmd+Shift+4; Toshy turns that into Shift+Print
             (frozenset({"cmd", "shift"}), "4"): "SHIFT + Print"},
}

# ---- KDE ----------------------------------------------------------------------------------
KDE_MOD = {"super": "Meta", "ctrl": "Ctrl", "alt": "Alt", "shift": "Shift"}
KDE_KEY = {"space": "Space", "tab": "Tab", "enter": "Return", "escape": "Esc", "left": "Left", "print": "Print",
           "right": "Right", "up": "Up", "down": "Down", "backspace": "Backspace", "delete": "Del",
           "home": "Home", "end": "End", "pageup": "PgUp", "pagedown": "PgDown", "grave": "`", "minus": "-",
           "equal": "=", "period": ".", "slash": "/", "semicolon": ";", "apostrophe": "'", "bracketleft": "[",
           "bracketright": "]", "backslash": "\\"}


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
    "app.switch.next": (SC, ["kwin"], "Walk Through Windows", ["Meta+Tab"]),           # KDE default extra
    "app.switch.prev": (SC, ["kwin"], "Walk Through Windows (Reverse)", ["Meta+Shift+Tab"]),
    "app.switch.windows": (SC, ["kwin"], "Walk Through Windows of Current Application", []),
    "app.switch.windows.prev": (SC, ["kwin"], "Walk Through Windows of Current Application (Reverse)", []),
    "layout.next":  (SC, ["KDE Keyboard Layout Switcher"], "Switch to Next Keyboard Layout", []),
    "launcher":     (SC, ["services", "org.kde.krunner.desktop"], "_launch", ["Search"]),
    "window.close": (SC, ["kwin"], "Window Close", []),
}


def kde():
    rows = [("kwinrc", "Desktops", "Number", str(N))]
    for action, (file, groups, key, extra) in KDE_ACTIONS.items():
        keys = [kde_combo(c) for c in binds["kde"].get(action, [])] + extra
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
            "delete": "Delete", "left": "Left", "right": "Right", "up": "Up", "down": "Down", "home": "Home",
            "end": "End", "pageup": "Prior", "pagedown": "Next", "print": "Print"}   # the rest: keysym = name


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
    **{f"desktop.take.{n}": f"hl.dsp.window.move({{ workspace = {n}, follow = true }})" for n in range(1, N + 1)},
    "desktop.prev": _step("- 1"),
    "desktop.next": _step("+ 1"),
    "desktop.move.prev": _step("- 1", _move),
    "desktop.move.next": _step("+ 1", _move),
    "desktop.last": 'hl.dsp.focus({ workspace = "previous" })',
    "scratchpad.toggle": 'hl.dsp.workspace.toggle_special("scratchpad")',
    "scratchpad.move": 'hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })',
    "layout.next": 'hl.dsp.exec_cmd("hyprctl switchxkblayout all next")',
    "launcher": "hl.dsp.exec_cmd(P.launcher)",
    "launcher.alt": "hl.dsp.exec_cmd(P.launcher_alt)",
    "terminal": "hl.dsp.exec_cmd(P.terminal)",
    **{f"window.focus.{d}": f'hl.dsp.focus({{ direction = "{d}" }})' for d in DIRS},
    **{f"window.move.{d}": f'hl.dsp.window.move({{ direction = "{d}" }})' for d in DIRS},
    **{f"window.swap.{d}": f'hl.dsp.window.swap({{ direction = "{d}" }})' for d in DIRS},
    # left/right: narrower/wider, up/down: shorter/taller (held down: repeats)
    **{f"window.resize.{d}": f"hl.dsp.window.resize({{ x = {x}, y = {y}, relative = true }})"
       for d, (x, y) in {"left": (-60, 0), "down": (0, 60), "up": (0, -60), "right": (60, 0)}.items()},
    "window.close": "hl.dsp.window.close()",
    "window.fullscreen": 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })',
    "window.maximize": 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })',
    "window.float": 'hl.dsp.window.float({ action = "toggle" })',
    "window.pin": "hl.dsp.window.pin()",
    "window.center": "hl.dsp.window.center()",
    "window.split": 'hl.dsp.layout("togglesplit")',
    "group.toggle": "hl.dsp.group.toggle()",
    "group.next": "hl.dsp.group.next()",
    "group.prev": "hl.dsp.group.prev()",
    "session.exit": "hl.dsp.exit()",
    "session.reload": "hl.dsp.reload_config()",
    "help.keys": 'hl.dsp.exec_cmd("qs ipc call keybinds toggle")',
    "panel.control": 'hl.dsp.exec_cmd("qs ipc call controlcenter toggle")',
    "panel.notifications": 'hl.dsp.exec_cmd("qs ipc call notifications toggle")',
    "panel.settings": 'hl.dsp.exec_cmd("qs ipc call settings toggle")',
    # quickshell/AppSwitcher.qml; it switches when Alt (= Cmd) is let go
    "app.switch.next": 'hl.dsp.global("quickshell:switcher-next")',
    "app.switch.prev": 'hl.dsp.global("quickshell:switcher-prev")',
    "app.switch.windows": 'hl.dsp.global("quickshell:switcher-windows")',
    "app.switch.windows.prev": 'hl.dsp.global("quickshell:switcher-windows-prev")',
    "screenshot.region": 'hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh")',
}


HYPR_REPEAT = ("window.resize.",)   # held down: repeat


def hypr():
    lines = ["-- generated by keys/build.py from keys/keymap.toml; do not edit",
             "-- usage in hyprland.lua: require(\"binds\")({ terminal = ..., launcher = ..., launcher_alt = ... })",
             "return function(P)"]
    for action, combos in binds["hypr"].items():
        opts = ", { repeating = true }" if action.startswith(HYPR_REPEAT) else ""
        lines += [f'  hl.bind("{hypr_combo(c)}", {HYPR_ACTIONS[action]}{opts}) -- {action}' for c in combos]
    return "\n".join(lines + ["end"]) + "\n"


# ---- model for Quickshell: Opt+? sheet + settings window's Shortcuts page ----------------------
# Every action in keymap.toml with its label, in sections. Keyed by the action as written in
# keymap.toml (placeholders unexpanded), so {n}/{dir} actions get one row each. Order = display.
SHEET = {
    "Desktops": {
        "desktop.goto.{n}":  "Go to desktop",
        "desktop.prev":      "Previous desktop",
        "desktop.next":      "Next desktop",
        "desktop.last":      "Desktop you were on before",
        "desktop.move.{n}":  "Send window to desktop",
        "desktop.take.{n}":  "Take window to desktop",
        "desktop.move.prev": "Send window to previous desktop",
        "desktop.move.next": "Send window to next desktop",
        "scratchpad.toggle": "Show / hide scratchpad",
        "scratchpad.move":   "Send window to scratchpad",
    },
    "Windows": {
        "window.focus.{dir}":  "Focus window",
        "window.move.{dir}":   "Move window",
        "window.swap.{dir}":   "Swap with window",
        "window.resize.{dir}": "Resize window",
        "window.close":        "Close window",
        "window.fullscreen":   "Fullscreen",
        "window.maximize":     "Maximize",
        "window.float":        "Floating",
        "window.pin":          "Pin floating window",
        "window.center":       "Center floating window",
        "window.split":        "Turn split sideways / up-down",
    },
    "Tab groups": {
        "group.toggle": "Make / undo a tab group",
        "group.next":   "Next tab",
        "group.prev":   "Previous tab",
    },
    "App switcher": {
        "app.switch.next":    "Switch app",
        "app.switch.prev":    "Switch app, backwards",
        "app.switch.windows": "In the switcher: that app's windows",
        "app.switch.windows.prev": "… backwards",
    },
    "Launch & type": {
        "launcher":     "Command palette",
        "launcher.alt": "Vicinae",
        "terminal":     "Terminal",
        "layout.next":  "Switch keyboard layout",
        "screenshot.region": "Screenshot key: drag an area",
    },
    "Panels": {
        "panel.control":       "Control center",
        "panel.notifications": "Notifications",
        "panel.settings":      "Settings",
        "help.keys":           "Keyboard shortcuts sheet",
    },
    "Session": {
        "session.reload": "Reload Hyprland config",
        "session.exit":   "Log out",
    },
}
# Binds that live in hyprland.lua, not keymap.toml (mouse); shown, not editable.
SHEET_EXTRA = {"Windows": [("Move window with mouse", ["⌥ drag"]),
                           ("Resize window with mouse", ["⌥ right-drag"])]}

MAC_MOD = {"ctrl": "⌃", "opt": "⌥", "shift": "⇧", "cmd": "⌘"}   # Apple's order
MAC_KEY = {"space": "Space", "enter": "↩", "escape": "Esc", "tab": "⇥", "backspace": "⌫", "delete": "⌦",
           "left": "←", "right": "→", "up": "↑", "down": "↓", "home": "↖", "end": "↘", "pageup": "⇞",
           "pagedown": "⇟", "slash": "/", "grave": "`", "minus": "-", "equal": "=", "period": ".",
           "semicolon": ";", "apostrophe": "'", "bracketleft": "[", "bracketright": "]", "backslash": "\\",
           "print": "Print"}
SHIFTED = {"slash": "?", "grave": "~"}   # shown as the shifted character, like macOS menus do


def mac_label(combo):
    """'opt+shift+{n}' -> '⌥ ⇧ 1–5', 'opt+shift+slash' -> '⌥ ?', 'opt+{dir}' -> '⌥ H J K L'"""
    *mods, key = combo.lower().replace(" ", "").split("+")
    if "shift" in mods and key in SHIFTED:
        mods.remove("shift"); key = SHIFTED[key]
    elif key == "{n}":
        key = f"1–{N}"
    elif key == "{dir}":
        key = " ".join(DIRS.values()).upper()
    else:
        key = MAC_KEY.get(key, key.upper())
    return " ".join([MAC_MOD[m] for m in MAC_MOD if m in mods] + [key])


def has_kde(action):
    return any(name in KDE_ACTIONS for name, _ in expand(action))


def model():
    groups = []
    for title, rows in SHEET.items():
        out = [{"action": a, "label": label, "hypr": src["hypr"][a], "hyprLabel": [mac_label(k) for k in src["hypr"][a]],
                "kde": src["kde"][a] if a in kde_own else None, "kdeLabel": [mac_label(k) for k in src["kde"][a]],
                "hasKde": has_kde(a)} for a, label in rows.items()]
        out += [{"label": l, "hyprLabel": k, "fixed": True} for l, k in SHEET_EXTRA.get(title, [])]
        groups.append({"title": title, "rows": out})
    return json.dumps({"desktops": N, "groups": groups}, indent=1, ensure_ascii=False) + "\n"


in_keymap, in_sheet = set(cfg["binds"]), {a for rows in SHEET.values() for a in rows}
assert not in_keymap - in_sheet, f"add {sorted(in_keymap - in_sheet)} to SHEET in keys/build.py (labels)"
assert not in_sheet - in_keymap, f"add {sorted(in_sheet - in_keymap)} to keys/keymap.toml (= [] if unbound)"
no_hypr = {a for a in in_keymap for name, _ in expand(a) if name not in HYPR_ACTIONS}
assert not no_hypr, f"no Hyprland action for {sorted(no_hypr)}: add them to HYPR_ACTIONS"
missing = {n for n in HYPR_ACTIONS} - {n for a in in_keymap for n, _ in expand(a)}
assert not missing, f"add {sorted(missing)} to keys/keymap.toml (= [] if unbound)"
no_kde = sorted(a for a in kde_own if not has_kde(a))
assert not no_kde, f"{', '.join(no_kde)} has no KDE equivalent, so no kde key"

# the same key twice on one desktop
for plat, actions in (("hypr", HYPR_ACTIONS), ("kde", KDE_ACTIONS)):
    seen = {}
    for action, combos in binds[plat].items():
        if action not in actions:
            continue
        for c in combos:
            assert c not in seen, (f"{'+'.join(sorted(c[0]) + [c[1]])} is used twice on "
                                   f"{'Hyprland' if plat == 'hypr' else 'KDE'}: {seen[c]} and {action}")
            seen[c] = action

# ---- write --------------------------------------------------------------------------------
targets = {"keys/generated/kde.tsv": kde, "hypr/binds.lua": hypr, "quickshell/keymap.json": model}

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
