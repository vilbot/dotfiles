#!/usr/bin/env python3
"""Run a program in foot as if foot were the Linux console. Every terminal of the "None" desktop
goes through this (tty/term), so programs look the way they do on the real tty:

  - TERM=linux, no COLORTERM: programs pick the colours and features they'd use on the console
  - colours: 256-colour and 24-bit colours become one of the console's 16, the way the kernel
    does it (drivers/tty/vt/vt.c: rgb_foreground, rgb_background, rgb_from_256)
  - characters the console font doesn't have are drawn as its replacement glyph (U+FFFD)
  - Home, End and F1-F5 send what the console sends (TERM=linux describes those keys)

  python3 tty/console.py [COMMAND [ARGS...]]     # default: $SHELL -l
"""
import codecs
import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import tty
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psf2ttf  # noqa: E402  (the console font: which characters it has)


# ---- colours, as the kernel does them ---------------------------------------------------

def rgb_from_256(i):
    if i < 8:
        return (0xaa if i & 1 else 0, 0xaa if i & 2 else 0, 0xaa if i & 4 else 0)
    if i < 16:
        return (0xff if i & 1 else 0x55, 0xff if i & 2 else 0x55, 0xff if i & 4 else 0x55)
    if i < 232:
        i -= 16
        return (i // 36 * 255 // 6, i // 6 % 6 * 255 // 6, i % 6 * 255 // 6)
    v = i * 10 - 2312
    return (v, v, v)


def fg_params(r, g, b):
    """24-bit foreground -> SGR params for one of the 16 colours (sets or clears bold, like the kernel)."""
    m = max(r, g, b)
    ansi = (r > m // 2) | (g > m // 2) << 1 | (b > m // 2) << 2
    if ansi == 7 and m <= 0x55:
        return ["1", "30"]
    return ["1" if m > 0xaa else "22", str(30 + ansi)]


def bg_params(r, g, b):
    """Backgrounds err on the dark side: 8 colours, a channel counts from 0x80."""
    return [str(40 + (r >= 0x80) + (g >= 0x80) * 2 + (b >= 0x80) * 4)]


def sgr(params):
    """Rewrite one SGR's parameters, turning extended colours into console colours.
    Colon forms (38:2::r:g:b, 4:3) are read as their plain meaning; the console has no others."""
    p = []
    for group in params.split(";"):
        sub = group.split(":")
        if sub[0] in ("38", "48") and len(sub) > 1:
            if sub[1] == "2" and len(sub) == 6:
                del sub[2]  # colour-space id
            p += sub
        else:
            p.append(sub[0])
    out, i = [], 0
    while i < len(p):
        kind = p[i]
        n = [int(x) if x.isdigit() else 0 for x in p[i + 1:i + 5]]
        if kind in ("38", "48") and n[:1] == [5] and len(n) >= 2:
            rgb, i = rgb_from_256(n[1] & 0xFF), i + 3
        elif kind in ("38", "48") and n[:1] == [2] and len(n) >= 4:
            rgb, i = tuple(min(v, 255) for v in n[1:4]), i + 5
        else:
            if kind not in ("38", "48"):
                out.append(kind)
            i += 1
            continue
        out += fg_params(*rgb) if kind == "38" else bg_params(*rgb)
    return ";".join(out)


# ---- characters the console font has ----------------------------------------------------

def font_chars():
    try:
        _, _, _, cmap = psf2ttf.read_psf(psf2ttf.find(psf2ttf.console_font()))
        return set(cmap)
    except SystemExit:
        return None  # font missing: leave text alone


# ---- the output filter ------------------------------------------------------------------

SGR = re.compile(r"\x1b\[([0-9;:]*)m")
# escape sequences pass through untouched; only text between them is checked against the font
ESC = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|[PX^_][^\x1b]*\x1b\\|[ -/]*[0-~])")
INCOMPLETE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*|\][^\x07\x1b]*|[PX^_][^\x1b]*|[ -/]*)?\Z")


class Output:
    def __init__(self, chars):
        self.chars = chars
        self.decode = codecs.getincrementaldecoder("utf-8")("surrogateescape")
        self.held = ""
        self.cache = {}

    def glyph(self, ch):
        o = ord(ch)
        if o < 0x80 or self.chars is None:
            return ch
        r = self.cache.get(ch)
        if r is None:
            if o in self.chars or 0xDC80 <= o <= 0xDCFF:  # known, or a raw byte that wasn't UTF-8
                r = ch
            elif unicodedata.combining(ch) or unicodedata.category(ch) in ("Mn", "Me", "Cf"):
                r = ""
            else:
                r = "�" * (2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1)
            self.cache[ch] = r
        return r

    def text(self, s):
        if self.chars is None or s.isascii():
            return s
        return "".join(self.glyph(c) for c in s)

    def feed(self, data):
        s = self.held + self.decode.decode(data)
        m = INCOMPLETE.search(s)
        self.held, s = (s[m.start():], s[:m.start()]) if m else ("", s)
        out, pos = [], 0
        for e in ESC.finditer(s):
            out.append(self.text(s[pos:e.start()]))
            seq = e.group()
            sm = SGR.fullmatch(seq)
            out.append(f"\x1b[{sgr(sm.group(1))}m" if sm and ("38" in seq or "48" in seq) else seq)
            pos = e.end()
        out.append(self.text(s[pos:]))
        return "".join(out).encode("utf-8", "surrogateescape")


# ---- keys: what the console sends -------------------------------------------------------

KEYS = [(b"\x1bOH", b"\x1b[1~"), (b"\x1b[H", b"\x1b[1~"), (b"\x1bOF", b"\x1b[4~"), (b"\x1b[F", b"\x1b[4~"),
        (b"\x1bOP", b"\x1b[[A"), (b"\x1bOQ", b"\x1b[[B"), (b"\x1bOR", b"\x1b[[C"), (b"\x1bOS", b"\x1b[[D"),
        (b"\x1b[15~", b"\x1b[[E")]


def keys(data):
    for a, b in KEYS:
        if a in data:
            data = data.replace(a, b)
    return data


# ---- the pty ----------------------------------------------------------------------------

def main():
    cmd = sys.argv[1:] or [os.environ.get("SHELL", "/bin/sh"), "-l"]
    env = dict(os.environ, TERM="linux")
    env.pop("COLORTERM", None)
    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execvpe(cmd[0], cmd, env)
        except OSError as e:
            print(f"console.py: {cmd[0]}: {e.strerror}", file=sys.stderr)
            os._exit(127)

    def resize(*_):
        try:
            size = fcntl.ioctl(sys.stdin.fileno(), termios.TIOCGWINSZ, b"\0" * 8)
            fcntl.ioctl(fd, termios.TIOCSWINSZ, size)
        except OSError:
            pass
    resize()
    signal.signal(signal.SIGWINCH, resize)

    out = Output(font_chars())
    saved = termios.tcgetattr(sys.stdin.fileno())
    tty.setraw(sys.stdin.fileno())
    try:
        while True:
            try:
                ready, _, _ = select.select([sys.stdin.fileno(), fd], [], [])
            except InterruptedError:
                continue
            if fd in ready:
                try:
                    data = os.read(fd, 65536)
                except OSError:
                    data = b""
                if not data:
                    break
                os.write(sys.stdout.fileno(), out.feed(data))
            if sys.stdin.fileno() in ready:
                data = os.read(sys.stdin.fileno(), 4096)
                if not data:
                    break
                os.write(fd, keys(data))
    finally:
        termios.tcsetattr(sys.stdin.fileno(), termios.TCSAFLUSH, saved)
    os.close(fd)  # the program gets SIGHUP if it's still running
    code = os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1])
    sys.exit(code if code >= 0 else 128 - code)


if __name__ == "__main__":
    main()
