#!/usr/bin/env python3
"""What the settings panel (tty/panel.sh) shows and does, one tab per class below.

The open tab is remembered in $XDG_RUNTIME_DIR/tty-panel-tab; the commands work on it.
    panel.py header | footer   the tab line / the key hints
    panel.py list              rows: "what you see<TAB>id"
    panel.py keys              every key any tab uses (fzf binds each once)
    panel.py on KEY ID         fzf actions for KEY on this tab (nothing if it has no such key)
    panel.py go -1|+1|TAB      fzf actions that switch tabs in place
    panel.py do ACTION ID      run an action on a row (ACTION = a key of the tab's actions)
    panel.py click LINE COL ID fzf actions for a click on the key hints (as that key on the row)
    panel.py tab-at COL        fzf actions for a click on the tab line at column COL (from 1)
    panel.py refresh           (every second, in the background) the list again, as fzf actions;
                               nothing if the tab changed meanwhile (it would put the old one back)
    panel.py failed ID         mark ID's last change as failed (a background command did)

Changes that take a while (connecting, pairing) run in the background and their row says so
("connecting…") until the change shows, or "failed": $XDG_RUNTIME_DIR/tty-panel-pending.json.

A tab is a class with list() -> [(text, id)] and actions = {name: (key, hint, method)}.
Actions that need the terminal (asking for a password, a y/n) have "ask" in their method's name.
"""
import json, os, pathlib, re, shlex, subprocess, sys

GREY, YELLOW, RED, BOLD, OFF = "\x1b[90m", "\x1b[35m", "\x1b[31m", "\x1b[1m", "\x1b[0m"


def sh(*cmd, check=False):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if check and r.returncode:
        raise SystemExit(r.stderr.strip() or f"{cmd[0]} failed")
    return r.stdout


def bg(*cmd):
    """for slow commands (connecting): the list catches up on its own"""
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


PENDING = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "tty-panel-pending.json"
FAILED_FOR, PENDING_FOR = 6, 45   # seconds "failed" shows / a change may take before it's dropped


def pending():
    """{id: [what, since]} still current"""
    import time
    try:
        p = json.loads(PENDING.read_text())
    except (OSError, ValueError):
        p = {}
    now = time.time()
    return {k: v for k, v in p.items() if now - v[1] < (FAILED_FOR if v[0] == "failed" else PENDING_FOR)}


def mark(id, what=None):
    """set (what) or clear (None) the pending state of a row"""
    import time
    p = pending()
    if what:
        p[id] = [what, time.time()]
    else:
        p.pop(id, None)
    PENDING.write_text(json.dumps(p))


def track(id, what, *cmd):
    """run cmd in the background; the row shows `what…` meanwhile, "failed" if cmd fails"""
    mark(id, what)
    fail = shlex.join([sys.executable, str(pathlib.Path(__file__).resolve()), "failed", id])
    bg("sh", "-c", f"{shlex.join(cmd)} || {fail}")


def state(id, now, done, idle):
    """what a row's state column shows: a pending change until `done` says it's through"""
    p = pending().get(id)
    if p and p[0] == "failed":
        return f"{RED}failed{OFF}"
    if p and not done(p[0]):
        return f"{YELLOW}{p[0]}…{OFF}"
    if p:
        mark(id)
    return now if now else idle


def ask(question):
    print(f"\n  {question} [y/N] ", end="", flush=True)
    return sys.stdin.readline().strip().lower() == "y"


def bar(pct, width=12):
    n = round(min(pct, 100) / 100 * width)
    return "#" * n + "-" * (width - n)


def fit(s, n):
    return s[:n - 1] + "…" if len(s) > n else s.ljust(n)


# ---- sound ---------------------------------------------------------------------------------
class Sound:
    actions = {
        "down":    ("h", "volume -", "volume", -5),
        "up":      ("l", "volume +", "volume", +5),
        "mute":    ("m", "mute", "mute"),
        "default": ("enter", "default", "default"),
    }

    def list(self):
        rows = []
        default = {"sink": sh("pactl", "get-default-sink").strip(),
                   "source": sh("pactl", "get-default-source").strip()}
        for kind, label in (("sink", "out"), ("source", "in")):
            for d in json.loads(sh("pactl", "--format=json", "list", kind + "s") or "[]"):
                if d["name"].endswith(".monitor"):
                    continue
                rows.append(self.row(label, d["description"], d, d["name"] == default[kind], f"{kind}:{d['name']}"))
        for s in json.loads(sh("pactl", "--format=json", "list", "sink-inputs") or "[]"):
            p = s.get("properties", {})
            name = p.get("application.name") or p.get("media.name") or "app"
            rows.append(self.row("app", name, s, False, f"sink-input:{s['index']}"))
        return rows

    @staticmethod
    def row(label, name, d, is_default, id):
        pct = int(next(iter(d["volume"].values()))["value_percent"].rstrip("%"))
        star = YELLOW + "*" + OFF if is_default else " "
        level = f"{GREY}muted{OFF}" if d["mute"] else f"{bar(pct)} {pct:3}%"
        return (f"{star} {GREY}{label:4}{OFF}{fit(name, 30)} {level}", id)

    def volume(self, id, step):
        kind, name = id.split(":", 1)
        pct = 0
        for d in json.loads(sh("pactl", "--format=json", "list", kind + "s") or "[]"):
            if str(d.get("index")) == name or d.get("name") == name:
                pct = int(next(iter(d["volume"].values()))["value_percent"].rstrip("%"))
        sh("pactl", f"set-{kind}-volume", name, f"{max(0, min(100, pct + step))}%")

    def mute(self, id):
        kind, name = id.split(":", 1)
        sh("pactl", f"set-{kind}-mute", name, "toggle")

    def default(self, id):
        kind, name = id.split(":", 1)
        if kind in ("sink", "source"):
            sh("pactl", f"set-default-{kind}", name)


# ---- bluetooth -----------------------------------------------------------------------------
class Bluetooth:
    actions = {
        "connect": ("enter", "dis/connect", "connect"),
        "scan":    ("s", "scan for new", "scan"),
        "power":   ("o", "on/off", "power"),
        "forget":  ("x", "forget", "ask_forget"),
    }

    @staticmethod
    def macs(*filter):
        return {m.group(1): m.group(2) for m in re.finditer(r"^Device (\S+) (.*)$", sh("bluetoothctl", "devices", *filter), re.M)}

    def list(self):
        show = sh("bluetoothctl", "show")
        on = "Powered: yes" in show
        scanning = "Discovering: yes" in show
        adapter = ("on" if on else f"{GREY}off{OFF}") + (f"  {YELLOW}scanning…{OFF}" if scanning else "")
        rows = [(f"  {GREY}bluetooth{OFF} {adapter}", "adapter")]
        if not on:
            return rows
        paired, connected = self.macs("Paired"), self.macs("Connected")
        for mac, name in sorted(self.macs().items(), key=lambda kv: (kv[0] not in paired, kv[1].lower())):
            if mac not in paired and name.replace("-", ":") == mac:
                continue  # found by a scan but has no name: nothing to recognise it by
            on = mac in connected
            plain = f"{YELLOW}connected{OFF}" if on else "paired" if mac in paired else f"{GREY}new{OFF}"
            shown = state(mac, plain, lambda what: on == (what != "disconnecting"), plain)
            star = YELLOW + "*" + OFF if on else " "
            rows.append((f"{star} {fit(name, 34)} {shown}", mac))
        return rows

    def connect(self, id):
        if id == "adapter":
            return self.power(id)
        if id in self.macs("Connected"):
            track(id, "disconnecting", "bluetoothctl", "disconnect", id)
        elif id in self.macs("Paired"):
            track(id, "connecting", "bluetoothctl", "connect", id)
        else:
            track(id, "pairing", "sh", "-c", f"bluetoothctl pair {id} && bluetoothctl trust {id} && bluetoothctl connect {id}")

    SCAN = ["bluetoothctl", "--timeout", "30", "scan", "on"]  # only this process can stop its scan

    def scan(self, id):
        if subprocess.run(["pkill", "-fx", " ".join(self.SCAN)]).returncode:
            bg(*self.SCAN)

    def power(self, id):
        on = "Powered: yes" in sh("bluetoothctl", "show")
        sh("bluetoothctl", "power", "off" if on else "on")

    def ask_forget(self, id):
        if id != "adapter" and ask(f"forget {self.macs().get(id, id)}?"):
            sh("bluetoothctl", "remove", id)


# ---- network -------------------------------------------------------------------------------
def nm(*fields_and_args):
    """nmcli -t output as lists of fields (':' separated, '\\:' escaped)"""
    out = sh("nmcli", "-t", *fields_and_args)
    return [[f.replace("\\:", ":") for f in re.split(r"(?<!\\):", line)] for line in out.splitlines() if line]


class Network:
    actions = {
        "connect": ("enter", "dis/connect", "ask_connect"),
        "wifi":    ("w", "wifi on/off", "wifi"),
        "rescan":  ("r", "look for wifi", "rescan"),
        "forget":  ("x", "forget", "ask_forget"),
    }

    def list(self):
        rows = []
        for dev, kind, st, con in nm("-f", "DEVICE,TYPE,STATE,CONNECTION", "device"):
            if kind not in ("ethernet", "wifi"):
                continue
            on = st.startswith("connected")
            label = "wired" if kind == "ethernet" else "wifi"
            plain = f"{YELLOW}{con}{OFF}" if on else f"{GREY}{st}{OFF}"
            shown = state(f"dev:{dev}", plain, lambda what: on == (what != "disconnecting"), plain)
            rows.append((f"{YELLOW + '*' + OFF if on else ' '} {GREY}{label:6}{OFF}{fit(dev, 12)} {shown}", f"dev:{dev}"))
        radio = sh("nmcli", "radio", "wifi").strip() == "enabled"
        rows.append((f"  {GREY}wifi{OFF}  {'on' if radio else GREY + 'off' + OFF}", "radio"))
        if radio:
            saved = {n for n, t in nm("-f", "NAME,TYPE", "connection", "show") if t == "802-11-wireless"}
            seen = set()
            for use, ssid, signal, security in nm("-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"):
                if not ssid or ssid in seen:
                    continue
                seen.add(ssid)
                on = use == "*"
                note = f"{GREY}{'saved' if ssid in saved else '' if security in ('', '--') else 'locked'}{OFF}"
                shown = state(f"ssid:{ssid}", "", lambda what, on=on: on == (what != "disconnecting"), note)
                star = YELLOW + "*" + OFF if on else " "
                rows.append((f"{star}   {fit(ssid, 30)} {bar(int(signal or 0), 6)} {shown}", f"ssid:{ssid}"))
        return rows

    def ask_connect(self, id):
        if id == "radio":
            return self.wifi(id)
        kind, name = id.split(":", 1)
        if kind == "dev":
            st = next((s for d, s in nm("-f", "DEVICE,STATE", "device") if d == name), "")
            if st.startswith("connected"):
                track(id, "disconnecting", "nmcli", "device", "disconnect", name)
            else:
                track(id, "connecting", "nmcli", "device", "connect", name)
            return
        if any(u == "*" and s == name for u, s in nm("-f", "IN-USE,SSID", "device", "wifi", "list", "--rescan", "no")):
            track(id, "disconnecting", "nmcli", "connection", "down", "id", name)
        elif any(n == name for n, in nm("-f", "NAME", "connection", "show")):
            track(id, "connecting", "nmcli", "connection", "up", "id", name)
        else:
            security = next((sec for s, sec in nm("-f", "SSID,SECURITY", "device", "wifi", "list", "--rescan", "no") if s == name), "")
            cmd = ["nmcli", "device", "wifi", "connect", name]
            if security not in ("", "--"):
                import getpass
                cmd += ["password", getpass.getpass(f"\n  password for {name}: ")]
            track(id, "connecting", *cmd)

    def wifi(self, id):
        on = sh("nmcli", "radio", "wifi").strip() == "enabled"
        sh("nmcli", "radio", "wifi", "off" if on else "on")

    def rescan(self, id):
        bg("nmcli", "device", "wifi", "rescan")

    def ask_forget(self, id):
        kind, _, name = id.partition(":")
        saved = any(n == name for n, in nm("-f", "NAME", "connection", "show"))
        if kind == "ssid" and saved and ask(f"forget {name}?"):
            sh("nmcli", "connection", "delete", "id", name)


TABS = {"sound": Sound, "bluetooth": Bluetooth, "network": Network}
COMMON = [("j/k", "move"), ("H/L", "tab"), ("q", "close")]
STATE = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "tty-panel-tab"
ME = shlex.quote(str(pathlib.Path(__file__).resolve()))


def current():
    try:
        tab = STATE.read_text().strip()
    except OSError:
        tab = ""
    return tab if tab in TABS else next(iter(TABS))


def tab_at(col):
    """the tab whose name is at column COL of the tab line ("  sound   bluetooth   network")"""
    start = 3
    for n in TABS:
        if start <= col < start + len(n):
            return n
        start += len(n) + 3
    return None


def header(tab):
    return "  " + "   ".join(f"{BOLD}{YELLOW}{n}{OFF}" if n == tab else f"{GREY}{n}{OFF}" for n in TABS)


def footer(tab):
    own = [(k if k != "enter" else "⏎", hint) for k, hint, *_ in TABS[tab].actions.values()]
    line = lambda pairs: "  " + "  ".join(f"{YELLOW}{k}{OFF} {h}" for k, h in pairs)
    return line(own) + "\n" + line(COMMON)


def footer_spans(tab):
    """[(line, first column, last column, key)] of the hints, as fzf counts (from 1)"""
    spans = []
    for line, pairs in enumerate([[(k, h) for k, h, *_ in TABS[tab].actions.values()], COMMON], 1):
        col = 3
        for k, h in pairs:
            text = f"{'⏎' if k == 'enter' else k} {h}"
            spans.append((line, col, col + len(text) - 1, k))
            col += len(text) + 2
    return spans


def keys():
    """every key some tab uses (fzf binds them all once; `on` says what they do on this tab)"""
    return sorted({key for t in TABS.values() for key, *_ in t.actions.values()})


def show(tab):
    """fzf actions that turn the panel to TAB in place (no restart, so no flicker)"""
    STATE.write_text(tab)
    # header and footer first: after a reload fzf looks for the row it tracked and drops actions
    return f"transform-header({ME} header)+transform-footer({ME} footer)+reload-sync({ME} list)"


def main():
    cmd, args = sys.argv[1], sys.argv[2:]
    tab = current()
    t = TABS[tab]()
    if cmd == "header":
        print(header(tab))
    elif cmd == "footer":
        print(footer(tab))
    elif cmd == "keys":
        print(" ".join(keys()))
    elif cmd == "list":
        try:
            for text, id in t.list():
                print(f"{text}\t{id}")
        except Exception as e:  # a tool missing or failing: say so instead of an empty list
            print(f"  {RED}{e}{OFF}\t-")
    elif cmd == "go":               # go -1 | go +1 | go TAB
        names = list(TABS)
        to = args[0] if args[0] in TABS else names[(names.index(tab) + int(args[0])) % len(names)]
        print(show(to))
    elif cmd == "on":               # on KEY ID: the fzf actions KEY means on this tab
        key, id = args
        hit = next(((name, method) for name, (k, _, method, *_) in t.actions.items() if k == key), None)
        if hit and id != "-":
            run = "execute" if hit[1].startswith("ask") else "execute-silent"
            print(f"{run}({ME} do {hit[0]} {shlex.quote(id)})+reload-sync({ME} list)")
    elif cmd == "click":            # click LINE COL ID: a click on the key hints
        line, col, id = int(args[0]), int(args[1]), args[2]
        key = next((k for l, a, b, k in footer_spans(tab) if l == line and a <= col <= b), None)
        if key == "H/L":
            print(show(list(TABS)[(list(TABS).index(tab) + 1) % len(TABS)]))
        elif key == "q":
            print(f"execute-silent({shlex.quote(str(pathlib.Path(__file__).resolve().parent.parent / 'panel.sh'))} close)")
        elif key and key != "j/k":
            sys.argv = [sys.argv[0], "on", key, id]
            main()
    elif cmd == "refresh":
        cache = STATE.with_name("tty-panel-list")
        rows = "".join(f"{text}\t{id}\n" for text, id in t.list())
        if current() == tab:   # still the same tab
            cache.write_text(rows)
            print(f"reload-sync(cat {shlex.quote(str(cache))})")
    elif cmd == "tab-at":           # tab-at COL: a click on the tab line (fzf's clicked "word" is
        to = tab_at(int(args[0]))   # the whole line: the rows' tab delimiter applies to it too)
        if to:
            print(show(to))
    elif cmd == "failed":           # failed ID
        mark(args[0], "failed")
    elif cmd == "do":               # do ACTION ID
        action, id = args
        _, _, method, *extra = t.actions[action]
        getattr(t, method)(id, *extra)


if __name__ == "__main__":
    main()
