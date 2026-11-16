#!/usr/bin/env python3
"""What the settings panel (tty/panel.sh) shows and does, one tab per class below.

The open tab is remembered in $XDG_RUNTIME_DIR/tty-panel-tab; the commands work on it.
    panel.py header | footer   the tab line / the key hints
    panel.py list              rows: "what you see<TAB>id"
    panel.py keys              every key any tab uses (fzf binds each once)
    panel.py on KEY ID         fzf actions for KEY on this tab (nothing if it has no such key)
    panel.py go -1|+1|TAB      fzf actions that switch tabs in place
    panel.py do ACTION ID      run an action on a row (ACTION = a key of the tab's actions)

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
        mark = YELLOW + "*" + OFF if is_default else " "
        level = f"{GREY}muted{OFF}" if d["mute"] else f"{bar(pct)} {pct:3}%"
        return (f"{mark} {GREY}{label:4}{OFF}{fit(name, 30)} {level}", id)

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
        state = ("on" if on else f"{GREY}off{OFF}") + (f"  {YELLOW}scanning…{OFF}" if scanning else "")
        rows = [(f"  {GREY}bluetooth{OFF} {state}", "adapter")]
        if not on:
            return rows
        paired, connected = self.macs("Paired"), self.macs("Connected")
        for mac, name in sorted(self.macs().items(), key=lambda kv: (kv[0] not in paired, kv[1].lower())):
            if mac not in paired and name.replace("-", ":") == mac:
                continue  # found by a scan but has no name: nothing to recognise it by
            if mac in connected:
                state = f"{YELLOW}connected{OFF}"
            elif mac in paired:
                state = "paired"
            else:
                state = f"{GREY}new{OFF}"
            mark = YELLOW + "*" + OFF if mac in connected else " "
            rows.append((f"{mark} {fit(name, 34)} {state}", mac))
        return rows

    def connect(self, id):
        if id == "adapter":
            return self.power(id)
        if id in self.macs("Connected"):
            bg("bluetoothctl", "disconnect", id)
        elif id in self.macs("Paired"):
            bg("bluetoothctl", "connect", id)
        else:
            bg("sh", "-c", f"bluetoothctl pair {id} && bluetoothctl trust {id} && bluetoothctl connect {id}")

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
        for dev, kind, state, con in nm("-f", "DEVICE,TYPE,STATE,CONNECTION", "device"):
            if kind not in ("ethernet", "wifi"):
                continue
            on = state.startswith("connected")
            label = "wired" if kind == "ethernet" else "wifi"
            what = f"{YELLOW}{con}{OFF}" if on else f"{GREY}{state}{OFF}"
            rows.append((f"{YELLOW + '*' + OFF if on else ' '} {GREY}{label:6}{OFF}{fit(dev, 12)} {what}", f"dev:{dev}"))
        radio = sh("nmcli", "radio", "wifi").strip() == "enabled"
        rows.append((f"  {GREY}wifi{OFF}  {'on' if radio else GREY + 'off' + OFF}", "radio"))
        if radio:
            saved = {n for n, t in nm("-f", "NAME,TYPE", "connection", "show") if t == "802-11-wireless"}
            seen = set()
            for use, ssid, signal, security in nm("-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"):
                if not ssid or ssid in seen:
                    continue
                seen.add(ssid)
                mark = YELLOW + "*" + OFF if use == "*" else " "
                note = "saved" if ssid in saved else "" if security in ("", "--") else "locked"
                rows.append((f"{mark}   {fit(ssid, 30)} {bar(int(signal or 0), 6)} {GREY}{note}{OFF}", f"ssid:{ssid}"))
        return rows

    def ask_connect(self, id):
        if id == "radio":
            return self.wifi(id)
        kind, name = id.split(":", 1)
        if kind == "dev":
            state = next((s for d, s in nm("-f", "DEVICE,STATE", "device") if d == name), "")
            sh("nmcli", "device", "disconnect" if state.startswith("connected") else "connect", name)
            return
        if any(u == "*" and s == name for u, s in nm("-f", "IN-USE,SSID", "device", "wifi", "list", "--rescan", "no")):
            sh("nmcli", "connection", "down", "id", name)
        elif any(n == name for n, in nm("-f", "NAME", "connection", "show")):
            print(f"\n  connecting to {name}…", flush=True)
            sh("nmcli", "connection", "up", "id", name)
        else:
            security = next((sec for s, sec in nm("-f", "SSID,SECURITY", "device", "wifi", "list", "--rescan", "no") if s == name), "")
            cmd = ["nmcli", "device", "wifi", "connect", name]
            if security not in ("", "--"):
                import getpass
                cmd += ["password", getpass.getpass(f"\n  password for {name}: ")]
            print(f"  connecting…", flush=True)
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode:
                print(f"  {r.stderr.strip()}\n  (any key)", flush=True)
                sys.stdin.readline()

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


def header(tab):
    return "  " + "   ".join(f"{BOLD}{YELLOW}{n}{OFF}" if n == tab else f"{GREY}{n}{OFF}" for n in TABS)


def footer(tab):
    own = [(k if k != "enter" else "⏎", hint) for k, hint, *_ in TABS[tab].actions.values()]
    line = lambda pairs: "  " + "  ".join(f"{YELLOW}{k}{OFF} {h}" for k, h in pairs)
    return line(own) + "\n" + line(COMMON)


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
    elif cmd == "do":               # do ACTION ID
        action, id = args
        _, _, method, *extra = t.actions[action]
        getattr(t, method)(id, *extra)


if __name__ == "__main__":
    main()
