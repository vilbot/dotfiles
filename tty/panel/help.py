#!/usr/bin/env python3
"""The settings panel's "help" tab: None's keys, and a support chat with a robot that means well.

    help.py      runs in the panel's terminal (panel.sh switches to it for the help tab)

Keys on top (mackeys' shortcut sheet, ~/.local/state/mackeys/keymap.json), the chat below. Type a
question, Enter asks. Up/Down scroll the keys, PgUp/PgDn the chat, Tab (or a click on a tab name)
another tab, Esc closes the panel. The robot is a model of your choosing (help.toml), allowed to
read None's files and nothing more; while it thinks, it narrates (funny-lines.txt, in order from
a random line; a long think ends on one of the file's last two lines).
"""
import curses, json, os, pathlib, random, shlex, subprocess, sys, textwrap, threading, time, tomllib

HERE = pathlib.Path(__file__).resolve().parent
TTY = HERE.parent
DOTFILES = TTY.parent
PANEL = TTY / "panel.sh"
STATE = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "tty-panel-tab"
KEYMAP = pathlib.Path.home() / ".local/state/mackeys/keymap.json"
TABS = ["sound", "bluetooth", "network", "help"]   # as panel.py's, plus this one
CONFIG = tomllib.loads((HERE / "help.toml").read_text())
LINES = [l.strip() for l in (HERE / "funny-lines.txt").read_text().splitlines() if l.strip()]
ENDERS, THINKING = LINES[-2:], LINES[:-2]   # the last two end a long think

PERSONA = """You are the support bot of "None", a keyboard-driven, all-terminal Linux desktop
(Hyprland; its files are in the tty/ folder of these dotfiles; its keys are in
keys/remap.toml and ~/.local/state/mackeys/keymap.json; AGENTS.md describes the layout).
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
            r = subprocess.run(cmd, cwd=DOTFILES, capture_output=True, text=True, timeout=180)
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
def keys_rows():
    try:
        groups = json.loads(KEYMAP.read_text())["groups"]
    except (OSError, ValueError, KeyError):
        return [("", "(no shortcut sheet yet: mackeys writes it)", "")]
    rows = []
    for g in groups:
        rows.append(("group", g.get("title", ""), ""))
        for r in g.get("rows", []):
            rows.append(("", r.get("label", ""), "  ".join(r.get("keysLabel", [])) or "—"))
    return rows


class Help:
    def __init__(self, scr):
        self.scr, self.bot = scr, Bot()
        self.keys, self.keys_top = keys_rows(), 0
        self.chat = [("bot", "Hi! I'm None's support robot. Ask me anything! I'll do my best. Probably.")]
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

    # ---- thinking ----
    def ask(self, q):
        self.chat.append(("you", q))
        self.chat_up = 0
        i = random.randrange(len(THINKING))
        self.thinking = {"since": time.time(), "i": i, "line": THINKING[i], "next": time.time() + 1.4, "ending": False}

        def work():
            try:
                self.answer = ("bot", self.bot.ask(q) or "…I forgot what I was going to say.")
            except Exception as e:
                self.answer = ("bot", f"Oops, I broke. ({str(e)[:200]})")
        threading.Thread(target=work, daemon=True).start()

    def tick(self):
        t = self.thinking
        if not t:
            return
        now = time.time()
        if self.answer and not t["ending"] and now - t["since"] > 6:
            t.update(ending=True, line=random.choice(ENDERS), next=now + 0.9)   # a long think ends
        elif self.answer and now >= t["next"] or self.answer and not t["ending"]:
            self.chat.append(self.answer)
            self.answer, self.thinking = None, None
        elif now >= t["next"] and not t["ending"]:
            t["i"] = (t["i"] + 1) % len(THINKING)   # the next line: they're written to follow on
            t.update(line=THINKING[t["i"]], next=now + 1.4)

    # ---- input ----
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


def main():
    os.environ.setdefault("ESCDELAY", "80")   # an arrow key is Esc + more: wait for the rest
    curses.wrapper(lambda scr: Help(scr).run())


if __name__ == "__main__":
    main()
