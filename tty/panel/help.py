#!/usr/bin/env python3
"""The settings panel's "help" tab: None's keys, and a support chat with a robot that means well.

    help.py      runs in the panel's terminal (panel.sh switches to it for the help tab)

Keys on top (tty/keys.json, as the Settings app's Shortcuts page shows them), the chat below. Type a
question, Enter asks. Up/Down scroll the keys, PgUp/PgDn the chat, Tab (or a click on a tab name)
another tab, Esc closes the panel. The robot is a model of your choosing (help.toml), allowed to
read None's files and nothing more; while it thinks, it narrates (funny-lines.txt, in order from
a random line; a long think ends on one of the file's last two lines). The chat stays when the
panel closes ($XDG_RUNTIME_DIR/tty-help-chat.json, until you log out), and so does a question
being answered: the robot answers in a process of its own (`help.py answer`), which adds the
answer to that file; the tab picks it up whenever it's open.
"""
import curses, json, os, pathlib, random, shlex, subprocess, sys, textwrap, time, tomllib

HERE = pathlib.Path(__file__).resolve().parent
TTY = HERE.parent
PANEL = TTY / "panel.sh"
STATE = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "tty-panel-tab"
USER = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "none"   # yours
KEYMAP = TTY / "keys.json"
sys.path.insert(0, str(HERE))
from panel import TABS as _TABS   # the tab line, as the other tabs draw it
TABS = list(_TABS)
CHAT = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "tty-help-chat.json"
CONFIG = tomllib.loads((USER / "help.toml" if (USER / "help.toml").exists() else HERE / "help.toml").read_text())
LINES = [l.strip() for l in (HERE / "funny-lines.txt").read_text().splitlines() if l.strip()]
ENDERS, THINKING = LINES[-2:], LINES[:-2]   # the last two end a long think

PERSONA = """You are the support bot of "None", a keyboard-driven, all-terminal Linux desktop
(Hyprland; you are in the folder with its files: README.md says what it is, AGENTS.md describes
the layout; its keys are in keys.json, plain Linux keys: Super for the desktop, Ctrl in apps,
with the user's own changes in ~/.config/none/keys.json; its Settings app is settings/).
You are cheerful, a little dim, and easily impressed, like a junior support agent on their
first day: you misread things at first, ramble a bit, and then do get to the right answer.
Answer in at most four short lines of plain text: no markdown, no lists, no code blocks.
Only answer about None and how to use it. You can read files to find out, but you never change
anything, and you don't offer to."""


# ---- the model ------------------------------------------------------------------------------
class Bot:
    """one conversation; ask() blocks (run it in a thread)"""

    def __init__(self):
        self.session = None

    def ask(self, question):
        backend = CONFIG.get("backend", "claude")
        if backend == "claude":
            cmd = ["claude", "-p", question, "--model", CONFIG.get("model", "haiku"),
                   "--output-format", "json", "--tools", "Read,Grep,Glob",
                   "--append-system-prompt", PERSONA, "--setting-sources", "project"]
            if self.session:
                cmd += ["--resume", self.session]
            r = subprocess.run(cmd, cwd=TTY, capture_output=True, text=True, timeout=180)
            if r.returncode:
                raise RuntimeError((r.stderr or r.stdout).strip().splitlines()[-1:] or "claude failed")
            out = json.loads(r.stdout)
            self.session = out.get("session_id", self.session)
            return out.get("result", "").strip()
        # backend = "command": PERSONA + question on stdin, the reply on stdout (no memory)
        r = subprocess.run(shlex.split(CONFIG["command"]), input=PERSONA + "\n\n" + question,
                           capture_output=True, text=True, timeout=180)
        if r.returncode:
            raise RuntimeError(r.stderr.strip() or "the command failed")
        return r.stdout.strip()


# ---- the screen -----------------------------------------------------------------------------
MODS = {"SUPER": "Super", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift"}
SHOWN = {"Escape": "Esc", "BackSpace": "Backspace", "Return": "Enter", "KP_Enter": "Keypad Enter",
         "space": "Space", "slash": "/", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→",
         "{dir}": "H J K L", "{arrow}": "← ↓ ↑ →"}


def show(keys, desktops):
    """ "SUPER + SHIFT + {n}" -> "Super+Shift+1–5", as tty/shell/AppKeys.qml shows keys"""
    parts = [p.strip() for p in keys.split("+") if p.strip()]
    key = parts[-1] if parts else ""
    key = f"1–{desktops}" if key == "{n}" else SHOWN.get(key, key)
    return "+".join([MODS.get(m.upper(), m) for m in parts[:-1]] + [key])


def keys_rows():
    try:
        model = json.loads(KEYMAP.read_text())
    except (OSError, ValueError):
        return [("", "(can't read tty/keys.json)", "")]
    try:   # what you changed (the Settings app writes it)
        mine = json.loads((USER / "keys.json").read_text())
    except (OSError, ValueError):
        mine = {}
    n, notes = mine.get("desktops", model.get("desktops", 5)), model.get("notes", {})
    groups = [(s.get("title", ""), s.get("actions", {})) for s in model.get("sections", [])]
    groups += [(a.get("title", name), a.get("actions", {})) for name, a in model.get("apps", {}).items()]
    for _, actions in groups:
        for name, keys in mine.get("keys", {}).items():
            if name in actions:
                actions[name]["keys"] = keys
    rows = []
    for title, actions in groups:
        rows.append(("group", title, ""))
        for a in actions.values():
            rows.append(("", a.get("label", ""), "  ".join(show(k, n) for k in a.get("keys", [])) or "—"))
        rows += [("", label, keys) for label, keys in notes.get(title, [])]
    return rows


class Help:
    def __init__(self, scr):
        self.scr, self.bot = scr, Bot()
        self.keys, self.keys_top = keys_rows(), 0
        self.chat = [("bot", "Hi! I'm None's support robot. Ask me anything! I'll do my best. Probably.")]
        self.load()
        self.chat_up = 0            # lines scrolled up from the bottom
        self.text = ""
        self.thinking = None        # {"since", "line", "next"} while the bot works
        self.answer = None          # filled by the thread
        curses.curs_set(1)
        curses.use_default_colors()
        for i, c in enumerate([5, 4, 8, 1], 1):   # yellow (ANSI magenta), blue, grey, red
            curses.init_pair(i, c, -1)
        self.YELLOW, self.BLUE, self.GREY, self.RED = (curses.color_pair(i) for i in range(1, 5))
        curses.mousemask(curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED | curses.BUTTON4_PRESSED | curses.BUTTON5_PRESSED)
        scr.timeout(150)
        scr.clear()   # a full first paint: coming from the other tabs, their last frame is still up

    # ---- drawing ----
    def put(self, y, x, s, attr=0):
        h, w = self.scr.getmaxyx()
        if 0 <= y < h and x < w:
            try:
                self.scr.addstr(y, max(0, x), s[: max(0, w - x - (1 if y == h - 1 else 0))], attr)
            except curses.error:
                pass

    def bubble(self, who, text, width):
        """the lines of one chat bubble, as [(x, string, attr)] rows"""
        inner = max(10, int(width * 0.72) - 4)
        wrapped = []
        for para in text.splitlines() or [""]:
            wrapped += textwrap.wrap(para, inner) or [""]
        bw = max(len(l) for l in wrapped) + 4
        top, bottom = "╭" + "─" * (bw - 2) + "╮", "╰" + "─" * (bw - 2) + "╯"
        body = ["│ " + l.ljust(bw - 4) + " │" for l in wrapped]
        if who == "you":
            x = width - bw - 2
            return [(x, l, self.YELLOW) for l in [top, *body, bottom]]
        lines = [top, *body, bottom]
        attr = self.GREY if who == "think" else self.BLUE
        return [(2, ("[o_o] " if i == 1 else "      ") + l, attr) for i, l in enumerate(lines)]

    def draw(self):
        s = self.scr
        s.erase()
        h, w = s.getmaxyx()
        x = 2   # the tab line, as the other tabs draw it
        for t in TABS:
            self.put(0, x, t, (self.YELLOW | curses.A_BOLD) if t == "help" else self.GREY)
            x += len(t) + 3
        # keys: the top part
        split = max(6, (h - 4) * 2 // 5)
        self.put(2, 2, "keys", self.GREY)
        view = self.keys[self.keys_top: self.keys_top + split - 3]
        for i, (kind, label, keys) in enumerate(view):
            if kind == "group":
                self.put(3 + i, 2, label, self.BLUE | curses.A_BOLD)
            else:
                self.put(3 + i, 4, label)
                self.put(3 + i, max(4 + len(label) + 2, w - 2 - len(keys)), keys, self.YELLOW)
        self.put(split, 0, "─" * w, self.GREY)
        # the chat, bottom up, above the input line
        rows = []
        for who, text in self.chat:
            rows += self.bubble(who, text, w) + [(0, "", 0)]
        if self.thinking:
            rows += self.bubble("think", self.thinking["line"], w)
        top, bottom = split + 1, h - 3
        visible = rows[max(0, len(rows) - (bottom - top) - self.chat_up): len(rows) - self.chat_up or None]
        for i, (bx, line, attr) in enumerate(visible[-(bottom - top):]):
            self.put(top + i, bx, line, attr)
        self.put(h - 2, 2, "> ", self.YELLOW | curses.A_BOLD)
        self.put(h - 2, 4, self.text[-(w - 6):])
        self.put(h - 1, 2, "⏎ ask  ↑↓ keys  PgUp/PgDn chat  tab other tabs  esc close", self.GREY)
        s.move(h - 2, min(w - 2, 4 + len(self.text)))
        s.refresh()

    # ---- the chat, kept across the panel closing ----
    def load(self):
        saved = read_chat()
        if not saved:
            return
        self.chat = [tuple(m) for m in saved["chat"]] or self.chat
        self.bot.session = saved.get("session")
        if self.chat[-1][0] == "you":
            if alive(saved.get("pending")):   # still answering, from before the panel closed
                self.think()
            else:
                self.chat.append(("bot", "Oh! I lost my place there. Could you ask that again?"))

    def save(self, pending=None):
        try:
            CHAT.write_text(json.dumps({"chat": self.chat, "session": self.bot.session, "pending": pending}))
        except OSError:
            pass

    # ---- thinking ----
    def think(self):
        i = random.randrange(len(THINKING))
        self.thinking = {"since": time.time(), "i": i, "line": THINKING[i], "next": time.time() + 1.4, "ending": False}

    def ask(self, q):
        self.chat.append(("you", q))
        self.save(pending=True)   # the question first: the answering process reads it
        worker = subprocess.Popen([sys.executable, str(pathlib.Path(__file__).resolve()), "answer"],
                                  stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  start_new_session=True)
        self.save(pending=worker.pid)
        self.chat_up = 0
        self.think()

    def arrived(self):
        """the answer, once the answering process has written it"""
        saved = read_chat()
        if saved and len(saved["chat"]) > len(self.chat) and saved["chat"][-1][0] == "bot":
            self.bot.session = saved.get("session")
            return tuple(saved["chat"][-1])
        if saved and not alive(saved.get("pending")) and not self.answer:   # it died
            return ("bot", "Oops, I broke. (my answer got lost)")
        return None

    def tick(self):
        t = self.thinking
        if not t:
            return
        if not self.answer:
            self.answer = self.arrived()
        now = time.time()
        if self.answer and not t["ending"] and now - t["since"] > 6:
            t.update(ending=True, line=random.choice(ENDERS), next=now + 0.9)   # a long think ends
        elif self.answer and now >= t["next"] or self.answer and not t["ending"]:
            self.chat.append(self.answer)
            self.answer, self.thinking = None, None
            self.save()
        elif now >= t["next"] and not t["ending"]:
            t["i"] = (t["i"] + 1) % len(THINKING)   # the next line: they're written to follow on
            t.update(line=THINKING[t["i"]], next=now + 1.4)

    # ---- input ----
    SEQUENCES = {"[A": curses.KEY_UP, "OA": curses.KEY_UP, "[B": curses.KEY_DOWN, "OB": curses.KEY_DOWN,
                 "[5~": curses.KEY_PPAGE, "[6~": curses.KEY_NPAGE, "[Z": curses.KEY_BTAB}

    def escape(self):
        """an Esc with more right behind it is a key curses didn't recognise (an arrow in the other
        cursor mode): that key, or "" to ignore it; a lone Esc: None"""
        self.scr.nodelay(True)
        rest = ""
        try:
            while len(rest) < 6:
                ch = self.scr.get_wch()
                rest += ch if isinstance(ch, str) else ""
        except curses.error:
            pass
        finally:
            self.scr.timeout(150)
        if not rest:
            return None
        return self.SEQUENCES.get(rest, "")
    def go(self, tab):
        STATE.write_text(tab)
        os.execv(str(PANEL), [str(PANEL), "run"])

    def run(self):
        while True:
            self.tick()
            self.draw()
            try:
                k = self.scr.get_wch()
            except curses.error:
                continue
            h, w = self.scr.getmaxyx()
            if k == "\x1b":
                k = self.escape()
                if k is None:   # a lone Esc
                    subprocess.run([str(PANEL), "close"])
                    return
            if k in ("\t", curses.KEY_BTAB):
                self.go(TABS[0] if k == "\t" else TABS[-2])
            elif k in ("\n", "\r", curses.KEY_ENTER):
                if self.text.strip() and not self.thinking:
                    self.ask(self.text.strip())
                    self.text = ""
            elif k in (curses.KEY_BACKSPACE, "\x7f", "\b"):
                self.text = self.text[:-1]
            elif k == "\x15":   # Ctrl+U
                self.text = ""
            elif k == curses.KEY_UP:
                self.keys_top = max(0, self.keys_top - 1)
            elif k == curses.KEY_DOWN:
                self.keys_top = min(max(0, len(self.keys) - 3), self.keys_top + 1)
            elif k == curses.KEY_PPAGE:
                self.chat_up += 5
            elif k == curses.KEY_NPAGE:
                self.chat_up = max(0, self.chat_up - 5)
            elif k == curses.KEY_MOUSE:
                try:
                    _, mx, my, _, b = curses.getmouse()
                except curses.error:
                    continue
                if b & curses.BUTTON4_PRESSED:
                    self.chat_up += 2
                elif b & curses.BUTTON5_PRESSED:
                    self.chat_up = max(0, self.chat_up - 2)
                elif my == 0:   # the tab line
                    x = 2
                    for t in TABS:
                        if x <= mx < x + len(t) and t != "help":
                            self.go(t)
                        x += len(t) + 3
            elif isinstance(k, str) and k.isprintable():
                self.text += k


def read_chat():
    try:
        saved = json.loads(CHAT.read_text())
        return saved if isinstance(saved.get("chat"), list) and saved["chat"] else None
    except (OSError, ValueError, AttributeError):
        return None


def alive(pid):
    if pid is True:   # just asked: the process is starting
        return True
    try:
        os.kill(int(pid), 0)
        return True
    except (TypeError, ValueError, OSError):
        return False


def answer():
    """`help.py answer`: answer the chat's last question, and add the answer to the chat"""
    saved = read_chat()
    bot = Bot()
    bot.session = saved.get("session")
    try:
        reply = bot.ask(saved["chat"][-1][1]) or "…I forgot what I was going to say."
    except Exception as e:
        reply = f"Oops, I broke. ({str(e)[:200]})"
    saved = read_chat() or saved   # as it is now
    saved["chat"].append(["bot", reply])
    saved.update(session=bot.session, pending=None)
    CHAT.write_text(json.dumps(saved))


def main():
    if sys.argv[1:] == ["answer"]:
        return answer()
    # from the other tabs, fzf hands over its own input (the list's pipe) and output (/dev/null):
    # draw on, and read from, the terminal itself
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        tty = os.open("/dev/tty", os.O_RDWR)
        os.dup2(tty, 0)
        os.dup2(tty, 1)
    os.environ.setdefault("ESCDELAY", "80")   # an arrow key is Esc + more: wait for the rest
    curses.wrapper(lambda scr: Help(scr).run())


if __name__ == "__main__":
    main()
