#!/usr/bin/env python3
"""The settings panel's "update" tab while an update runs: CachyOS's updater (cachy-update, which
is arch-update) in a terminal of its own that outlives the panel. Close the panel and the update
goes on; open the tab again and it's all there, still going (a small dtach: the update runs in a
pty held by a background process; the tab shows everything it printed and passes your keys on).

    update.py start      start an update in the background, unless one is running
    update.py attach     the tab: the update's output, live (or how the last one ended)
    update.py active     exit 0 when there's something for attach to show
    update.py seen       forget how the last update ended (its red in the bar goes)
    update.py daemon     (start runs it) the update itself

Files in $XDG_RUNTIME_DIR/none-update/: sock (attach connects to it), log (all it printed),
state (the bar's update icon reads it, tty/shell/Status.qml):
    running   it's working
    waiting   it waits for you (a password, a y/n): nothing printed for a moment and the last
              line asks something
    done      it finished               stopped   you said no (or another one was running)
    failed N  it failed with exit status N
    (empty)   nothing to show: the tab shows the list of updates (panel.py)
Its "Press enter to quit" at the end gets its Enter by itself: the tab says how it ended instead.

In the tab: Tab / Shift+Tab (or a click on the tab line) another tab, Esc closes the panel (the
update goes on), everything else goes to the update. Once it's over: Enter back to the list.
"""
import fcntl, os, pathlib, pty, re, select, signal, socket, struct, subprocess, sys, termios, time, tty

HERE = pathlib.Path(__file__).resolve().parent
PANEL = HERE.parent / "panel.sh"
RUN = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "none-update"
SOCK, LOG, STATE = RUN / "sock", RUN / "log", RUN / "state"
TABFILE = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "tty-panel-tab"
COMMAND = ["arch-update"]

ANSI = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[@-Z\\-_]")
# the last line, after a pause, when it asks you something: "[sudo] password for x: ",
# "Proceed with installation? [Y/n] ", "... or press "enter" to proceed with update: "
PROMPT = re.compile(rb"(\[[yY]/[nN]\]|password|:|\?)\s*$", re.I)
QUIT = re.compile(rb'press "enter" to quit', re.I)
QUIET = 0.6   # seconds without output before a prompt counts as waiting


def state():
    try:
        return STATE.read_text().strip()
    except OSError:
        return ""


def set_state(s):
    RUN.mkdir(parents=True, exist_ok=True)
    STATE.write_text(s + "\n")


def running():
    try:
        with socket.socket(socket.AF_UNIX) as s:
            s.connect(str(SOCK))
        return True
    except OSError:
        return False


# ---- the update, in the background ------------------------------------------------------------
def daemon():
    RUN.mkdir(parents=True, exist_ok=True)
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.setdefault("TERM", "foot")
        try:
            os.execvp(COMMAND[0], COMMAND)
        finally:
            os._exit(127)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 80, 0, 0))
    log = open(LOG, "wb")
    try:
        SOCK.unlink()
    except OSError:
        pass
    srv = socket.socket(socket.AF_UNIX)
    srv.bind(str(SOCK))
    srv.listen()
    set_state("running")
    clients, inbox = [], {}
    tail, last_out, quit_sent, now_state = b"", time.time(), False, "running"

    def to_all(data):
        for c in clients[:]:
            try:
                c.sendall(data)
            except OSError:
                clients.remove(c)

    while True:
        ready, _, _ = select.select([fd, srv, *clients], [], [], 0.2)
        if fd in ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b""
            if not data:
                break   # it's over
            log.write(data)
            log.flush()
            to_all(data)
            tail = (tail + data)[-2000:]
            last_out = time.time()
            if now_state != "running":
                now_state = "running"
                set_state(now_state)
        if srv in ready:
            c, _ = srv.accept()
            try:
                c.sendall(LOG.read_bytes())   # everything so far, then what comes
                clients.append(c)
                inbox[c] = b""
            except OSError:
                c.close()
        for c in [c for c in clients if c in ready]:
            try:
                got = c.recv(65536)
            except OSError:
                got = b""
            if not got:
                clients.remove(c)
                c.close()
                continue
            buf = inbox[c] + got
            # frames: kind (1 byte) + length (2 bytes) + payload; "i" = keys, "r" = rows, cols
            while len(buf) >= 3:
                kind, n = buf[:1], struct.unpack("!H", buf[1:3])[0]
                if len(buf) < 3 + n:
                    break
                payload, buf = buf[3:3 + n], buf[3 + n:]
                if kind == b"i":
                    os.write(fd, payload)
                elif kind == b"r":
                    rows, cols = struct.unpack("!HH", payload)
                    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            inbox[c] = buf
        if time.time() - last_out > QUIET:
            line = ANSI.sub(b"", tail).replace(b"\r\n", b"\n").split(b"\n")[-1].split(b"\r")[-1]
            if QUIT.search(line) and not quit_sent:
                os.write(fd, b"\r")   # the tab says how it ended; no need to press anything
                quit_sent = True
            elif PROMPT.search(line) and not QUIT.search(line) and now_state != "waiting":
                now_state = "waiting"
                set_state(now_state)
    _, status = os.waitpid(pid, 0)
    code = os.waitstatus_to_exitcode(status)
    # 4: you said no to "Proceed with update?"; 17: no to running a second one
    set_state("done" if code == 0 else "stopped" if code in (4, 17) else f"failed {code}")
    for c in clients:
        c.close()
    srv.close()
    try:
        SOCK.unlink()
    except OSError:
        pass


def start():
    if running():
        return
    LOG.parent.mkdir(parents=True, exist_ok=True)
    LOG.write_bytes(b"")
    set_state("running")
    subprocess.Popen([sys.executable, __file__, "daemon"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(50):   # until it takes visitors
        if running():
            return
        time.sleep(0.02)


# ---- the tab ---------------------------------------------------------------------------------
GREY, YELLOW, GREEN, RED, BOLD, OFF = "\x1b[90m", "\x1b[35m", "\x1b[32m", "\x1b[31m", "\x1b[1m", "\x1b[0m"


class Attach:
    def __init__(self):
        sys.path.insert(0, str(HERE))
        import panel   # the tab line, as the other tabs draw it
        self.panel = panel
        self.out = sys.stdout.buffer
        self.sock = None
        self.alt = False   # the update shows a full-screen program (a pager, vimdiff): Esc is its

    def size(self):
        return os.get_terminal_size(0)

    def write(self, s):
        self.out.write(s if isinstance(s, bytes) else s.encode())
        self.out.flush()

    def chrome(self, footer):
        """the tab line at the top, the key hints at the bottom, the update in between (a
        scroll region with origin mode on: its row 1 is the region's first row)"""
        h, w = self.size().lines, self.size().columns
        self.write(("\x1b[?25h" if self.sock else "\x1b[?25l") + f"\x1b7\x1b[?6l\x1b[1;1H\x1b[2K{self.panel.header('update')}\x1b[2;1H\x1b[2K"
                   f"\x1b[{h};1H\x1b[2K  {footer}{OFF}\x1b[3;{h - 1}r\x1b[?6h\x1b8")

    def footer(self):
        s = state()
        keys = f"{YELLOW}tab{OFF} other tabs  {YELLOW}esc{OFF} close"
        if self.sock:
            now = f"{YELLOW}{BOLD}it asks you something{OFF}" if s == "waiting" else f"{GREY}goes on when the panel closes{OFF}"
            return f"{now}  {keys}"
        how = (f"{GREEN}{BOLD}updated{OFF}" if s == "done" else f"{GREY}stopped{OFF}" if s == "stopped"
               else f"{RED}{BOLD}failed (exit {s.split()[1]}){OFF}" if s.startswith("failed") else s)
        return f"{how}  {YELLOW}⏎{OFF} back to the list  {keys}"

    def send(self, kind, payload):
        if self.sock:
            try:
                self.sock.sendall(kind + struct.pack("!H", len(payload)) + payload)
            except OSError:
                pass

    def connect(self):
        try:
            self.sock = socket.socket(socket.AF_UNIX)
            self.sock.connect(str(SOCK))
        except OSError:
            self.sock = None

    def draw(self):
        """everything from the start, at this size: the update's output again from the top (a
        new connection gets it all), or how the last one ended"""
        if self.sock:
            self.sock.close()
        self.write("\x1b[?6l\x1b[r\x1b[2J\x1b[H")
        self.connect()
        self.chrome(self.footer())
        self.write("\x1b[?6h\x1b[H")
        if self.sock:
            h, w = self.size().lines, self.size().columns
            self.send(b"r", struct.pack("!HH", max(1, h - 3), w))
        else:
            try:
                self.write(LOG.read_bytes())
            except OSError:
                pass

    def leave(self):
        """the terminal as it was, for whatever comes next in it"""
        self.write("\x1b[?1000l\x1b[?1006l\x1b[?6l\x1b[r\x1b[2J\x1b[H\x1b[?25h")
        termios.tcsetattr(0, termios.TCSADRAIN, self.saved)

    def go(self, tab):
        self.leave()
        TABFILE.write_text(tab)
        os.execv(str(PANEL), [str(PANEL), "run"])

    def tab(self, by):
        names = list(self.panel.TABS)
        self.go(names[(names.index("update") + by) % len(names)])

    def close(self):
        self.leave()
        subprocess.run([str(PANEL), "close"])
        sys.exit(0)

    def keys(self, data):
        """keys from you: the tab's own, the rest to the update"""
        if data == b"\t":
            return self.tab(+1)
        if data == b"\x1b[Z":
            return self.tab(-1)
        if data == b"\x1b" and not self.alt:
            return self.close()
        clicks = list(re.finditer(rb"\x1b\[<(\d+);(\d+);(\d+)([Mm])", data))
        if clicks:   # mouse: only a click on the tab line means something
            for m in clicks:
                if m.group(1) == b"0" and m.group(4) == b"M" and m.group(3) == b"1":
                    to = self.panel.tab_at(int(m.group(2)))
                    if to and to != "update":
                        return self.go(to)
            return
        if self.sock:
            self.send(b"i", data)
        elif data in (b"\r", b"\n"):
            subprocess.run([sys.executable, __file__, "seen"])
            self.go("update")
        elif data == b"q":
            self.close()

    def run(self):
        self.saved = termios.tcgetattr(0)
        tty.setraw(0)
        self.write("\x1b[?1000h\x1b[?1006h")
        self.draw()
        resized = []
        signal.signal(signal.SIGWINCH, lambda *_: resized.append(1))
        shown = state()
        while True:
            if resized:   # (the window takes its size just after it opens, too)
                resized.clear()
                self.alt = False
                self.draw()
            try:
                ready, _, _ = select.select([0] + ([self.sock] if self.sock else []), [], [], 0.15)
            except InterruptedError:
                continue
            if self.sock and self.sock in ready:
                data = self.sock.recv(65536)
                if not data:   # it ended
                    self.sock.close()
                    self.sock = None
                    for _ in range(20):   # its last word (the state) comes right after
                        if state() not in ("running", "waiting"):
                            break
                        time.sleep(0.05)
                    self.chrome(self.footer())
                else:
                    for m in re.finditer(rb"\x1b\[\?(?:1049|1047|47)([hl])", data):
                        self.alt = m.group(1) == b"h"
                    self.write(data)
            if 0 in ready:
                data = os.read(0, 4096)
                if not data:
                    return
                self.keys(data)
            if state() != shown:   # waiting / running: the hint at the bottom says so
                shown = state()
                self.chrome(self.footer())


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "daemon":
        daemon()
    elif cmd == "start":
        start()
    elif cmd == "active":
        sys.exit(0 if running() or state() else 1)
    elif cmd == "seen":
        if not running():
            set_state("")
    elif cmd == "attach":
        # from the other tabs fzf hands over its own input and output (a pipe, /dev/null): use
        # the terminal itself
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            t = os.open("/dev/tty", os.O_RDWR)
            os.dup2(t, 0)
            os.dup2(t, 1)
        Attach().run()
    else:
        print(__doc__.split("\n\n")[1])
        sys.exit(2)


if __name__ == "__main__":
    main()
