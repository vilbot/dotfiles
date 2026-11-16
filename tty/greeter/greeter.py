#!/usr/bin/env python3
"""The login form in the login screen's terminal (greeter.lua), talking to greetd.

      desktop   [None]  Hyprland  KDE
      login     you
      password

Up/Down (or Tab/Shift+Tab) move between the lines; on the desktop line Left/Right (or h/l)
pick the desktop. Enter goes to the next line; on the password it logs in. The desktop and the
name are remembered, so usually it starts on the password. Keys are in the bottom line.
greetd's protocol: https://man.archlinux.org/man/greetd-ipc.7
"""
import json, os, pathlib, shlex, signal, socket, struct, subprocess, sys, termios, tty

SESSIONS = pathlib.Path("/etc/greetd/sessions")
STATE = pathlib.Path("/var/cache/none-greeter/state.json")
GREY, RED, YELLOW, BOLD, OFF = "\x1b[90m", "\x1b[31m", "\x1b[35m", "\x1b[1m", "\x1b[0m"
UP, DOWN, LEFT, RIGHT = ("\x1b[A", "\x1bOA"), ("\x1b[B", "\x1bOB"), ("\x1b[D", "\x1bOD"), ("\x1b[C", "\x1bOC")
DESKTOP, LOGIN, PASSWORD = 0, 1, 2


def sessions():
    out = []
    for f in sorted(SESSIONS.glob("*.desktop")):
        kv = dict(l.split("=", 1) for l in f.read_text().splitlines() if "=" in l)
        out.append((kv.get("Name", f.stem), kv.get("Exec", "")))
    return out


def load():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


class Greetd:
    def __init__(self):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(os.environ["GREETD_SOCK"])

    def ask(self, **msg):
        data = json.dumps(msg).encode()
        self.s.sendall(struct.pack("=I", len(data)) + data)
        n = struct.unpack("=I", self.recv(4))[0]
        return json.loads(self.recv(n))

    def recv(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.s.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("greetd went away")
            buf += chunk
        return buf


def keys(chunk):
    """one read can hold several keys (fast typing, a paste); escape sequences stay whole"""
    i = 0
    while i < len(chunk):
        if chunk[i] == "\x1b" and chunk[i + 1:i + 2] == "O" and i + 2 < len(chunk):
            yield chunk[i:i + 3]
            i += 3
        elif chunk[i] == "\x1b" and chunk[i + 1:i + 2] == "[":
            j = i + 2
            while j < len(chunk) and not chunk[j].isalpha() and chunk[j] != "~":
                j += 1
            yield chunk[i:j + 1]
            i = j + 1
        else:
            yield chunk[i]
            i += 1


class Form:
    """the three lines, drawn whole after every key; extra = a further question from PAM"""

    def __init__(self, desktops, pick, user):
        self.desktops, self.pick = desktops, pick
        self.text = {LOGIN: user, PASSWORD: ""}
        self.field = PASSWORD if user else LOGIN
        self.message = ""
        self.extra = None   # (label, secret, text) while PAM asks something more

    def draw(self):
        def label(f, name):
            return f"{BOLD}{YELLOW}{name:<10}{OFF}" if self.field == f else f"{GREY}{name:<10}{OFF}"
        names = "  ".join(f"{BOLD}{YELLOW}[{n}]{OFF}" if i == self.pick else f"{GREY} {n} {OFF}"
                          for i, (n, _) in enumerate(self.desktops))
        rows = ["", f"  {label(DESKTOP, 'desktop')}{names}", f"  {label(LOGIN, 'login')}{self.text[LOGIN]}",
                f"  {label(PASSWORD, 'password')}{'*' * len(self.text[PASSWORD])}"]
        if self.extra:
            rows.append(f"  {BOLD}{YELLOW}{self.extra[0]}{OFF} " + ("" if self.extra[1] else self.extra[2]))
        rows += ["", f"  {self.message}"]
        out = "\x1b[H" + "".join(f"\x1b[2K{r}\r\n" for r in rows)
        hint = "↑↓ line   ←→ desktop   ⏎ " + ("log in" if self.field == PASSWORD else "next")
        out += f"\x1b[999;1H\x1b[2K  {GREY}{hint}{OFF}"
        # the cursor where you type
        if self.extra:
            row, col = 5, 3 + len(self.extra[0]) + 1 + (0 if self.extra[1] else len(self.extra[2]))
        elif self.field == DESKTOP:
            col = 3 + 10 + sum(len(n) + 4 for n, _ in self.desktops[:self.pick]) + 1
            row = 2
        else:
            row = 3 if self.field == LOGIN else 4
            col = 3 + 10 + len(self.text[self.field])
        sys.stdout.write(out + f"\x1b[{row};{col}H")
        sys.stdout.flush()

    def run(self):
        """until Enter on the password: returns (user, password, desktop index)"""
        while True:
            self.draw()
            for k in keys(os.read(sys.stdin.fileno(), 1024).decode(errors="ignore")):
                if k in ("\r", "\n"):
                    if self.field == PASSWORD:
                        return self.text[LOGIN], self.text[PASSWORD], self.pick
                    self.field += 1
                elif k in UP or k == "\x1b[Z":
                    self.field = max(DESKTOP, self.field - 1)
                elif k in DOWN or k == "\t":
                    self.field = min(PASSWORD, self.field + 1)
                elif self.field == DESKTOP:
                    if k in LEFT or k == "h":
                        self.pick = (self.pick - 1) % len(self.desktops)
                    elif k in RIGHT or k in ("l", " "):
                        self.pick = (self.pick + 1) % len(self.desktops)
                elif k in ("\x7f", "\x08"):
                    self.text[self.field] = self.text[self.field][:-1]
                elif k == "\x15":   # Ctrl+U
                    self.text[self.field] = ""
                elif k.isprintable() and len(k) == 1:
                    self.text[self.field] += k

    def ask(self, label, secret):
        """PAM asks more than the password (rare): one more line under the form"""
        self.extra = (label, secret, "")
        while True:
            self.draw()
            for k in keys(os.read(sys.stdin.fileno(), 1024).decode(errors="ignore")):
                lab, sec, text = self.extra
                if k in ("\r", "\n"):
                    self.extra = None
                    return text
                if k in ("\x7f", "\x08"):
                    text = text[:-1]
                elif k.isprintable() and len(k) == 1:
                    text += k
                self.extra = (lab, sec, text)


def login(form, g, user, password):
    """greetd's conversation; the first secret question gets the password from the form"""
    r = g.ask(type="create_session", username=user)
    given = False
    while r["type"] == "auth_message":
        kind, text = r["auth_message_type"], r["auth_message"].strip()
        if kind == "secret" and not given:
            answer, given = password, True
        elif kind in ("secret", "visible"):
            answer = form.ask(text or "?", kind == "secret")
        else:
            form.message = text
            answer = None
        r = g.ask(type="post_auth_message_response", response=answer)
    return r


def main():
    desktops = sessions() or [("None", "/bin/sh")]
    state = load()
    pick = next((i for i, (n, _) in enumerate(desktops) if n == state.get("desktop")), 0)
    form = Form(desktops, pick, state.get("user", ""))
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    tty.setraw(fd)
    sys.stdout.write("\x1b[2J")
    # the terminal changes size as the screen settles (the bar arrives): draw it all again
    signal.signal(signal.SIGWINCH, lambda *_: (sys.stdout.write("\x1b[2J"), form.draw()))
    try:
        while True:
            user, password, pick = form.run()
            g = None
            try:
                g = Greetd()
                r = login(form, g, user, password)
                if r["type"] == "success":
                    name, cmd = desktops[pick]
                    form.message = f"{GREY}starting {name}…{OFF}"
                    form.draw()
                    r = g.ask(type="start_session", cmd=shlex.split(cmd), env=[])
                if r["type"] == "success":
                    try:
                        STATE.write_text(json.dumps({"user": user, "desktop": name}))
                    except OSError:
                        pass
                    done = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "none-greeter-done"
                    done.touch()
                    sys.stdout.write("\x1b[2J\x1b[H")   # an empty terminal, as None starts with
                    sys.stdout.flush()
                    subprocess.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"], capture_output=True)
                    return
                g.ask(type="cancel_session")
                form.message = f"{RED}Login incorrect{OFF}"
            except Exception as e:  # greetd hiccup: say it, try again
                form.message = f"{RED}{e}{OFF}"
                try:
                    g and g.ask(type="cancel_session")
                except Exception:
                    pass
            form.text[PASSWORD] = ""
            form.field = PASSWORD
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


if __name__ == "__main__":
    main()
