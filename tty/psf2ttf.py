#!/usr/bin/env python3
"""Turn the console font (a PSF bitmap font) into a TrueType font made of square pixels, so foot
draws exactly what the tty draws. One font unit grid = one console pixel; at foot's
`pixelsize=<glyph height>` every pixel lands on a screen pixel.

  python3 tty/psf2ttf.py                 # font from /etc/vconsole.conf (FONT=), else ter-v32n
  python3 tty/psf2ttf.py FONT OUT.ttf    # FONT = name in /usr/share/kbd/consolefonts or a path
"""
import gzip
import os
import re
import struct
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib.tables.O_S_2f_2 import Panose

CONSOLEFONTS = "/usr/share/kbd/consolefonts"
DEFAULT_FONT = "ter-v32n"
OUT = os.path.expanduser("~/.local/share/fonts/tty-console.ttf")
FAMILY = "TTY Console"
UNIT = 64  # font units per console pixel


def console_font():
    """The FONT= of /etc/vconsole.conf, the font the tty uses."""
    try:
        with open("/etc/vconsole.conf") as f:
            m = re.search(r"^FONT=\"?([^\"\n]+)", f.read(), re.M)
            if m:
                return m.group(1)
    except OSError:
        pass
    return DEFAULT_FONT


def find(name):
    if os.path.sep in name:
        return name
    for ext in ("", ".psf.gz", ".psfu.gz", ".psf", ".psfu", ".gz"):
        path = os.path.join(CONSOLEFONTS, name + ext)
        if os.path.isfile(path):
            return path
    sys.exit(f"psf2ttf: console font {name!r} not found in {CONSOLEFONTS} (pacman -S terminus-font?)")


def read_psf(path):
    """-> (width, height, [glyph rows as ints], {codepoint: glyph index})"""
    data = open(path, "rb").read()
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    cmap = {}
    if data[:2] == b"\x36\x04":  # PSF1
        mode, height = data[2], data[3]
        width, count, size, off = 8, 512 if mode & 1 else 256, height, 4
        table = data[off + count * size:] if mode & 2 else b""
        g, i = 0, 0
        while g < count and i + 1 < len(table):
            (u,) = struct.unpack_from("<H", table, i)
            i += 2
            if u == 0xFFFF:
                g += 1
            elif u == 0xFFFE:  # sequences follow: skip to the glyph's end
                while i + 1 < len(table) and struct.unpack_from("<H", table, i)[0] != 0xFFFF:
                    i += 2
            else:
                cmap.setdefault(u, g)
    elif data[:4] == b"\x72\xb5\x4a\x86":  # PSF2
        _, off, flags, count, size, height, width = struct.unpack_from("<7I", data, 4)
        table = data[off + count * size:] if flags & 1 else b""
        g, i = 0, 0
        while g < count and i < len(table):
            end = table.index(b"\xff", i)
            entry = table[i:end].split(b"\xfe")[0]  # singles only, not sequences
            for ch in entry.decode("utf-8", "replace"):
                cmap.setdefault(ord(ch), g)
            g, i = g + 1, end + 1
    else:
        sys.exit(f"psf2ttf: {path} is not a PSF font")
    if not cmap:  # no unicode table: assume Latin-1 order
        cmap = {c: c for c in range(min(count, 256))}
    row_bytes = (width + 7) // 8
    glyphs = []
    for g in range(count):
        base = off + g * size
        rows = [int.from_bytes(data[base + r * row_bytes: base + (r + 1) * row_bytes], "big")
                for r in range(height)]
        glyphs.append(rows)
    return width, height, glyphs, cmap


def outline(rows, width, height):
    """Pixels as rectangles, one per horizontal run (clockwise, TrueType outer contours)."""
    pen = TTGlyphPen(None)
    shift = ((width + 7) // 8) * 8 - width
    for r, bits in enumerate(rows):
        bits >>= shift
        y1 = (height - r) * UNIT  # baseline at the bottom of the cell; descent handled by ascent
        y0 = y1 - UNIT
        x = 0
        while x < width:
            if bits >> (width - 1 - x) & 1:
                start = x
                while x < width and bits >> (width - 1 - x) & 1:
                    x += 1
                pen.moveTo((start * UNIT, y0))
                pen.lineTo((start * UNIT, y1))
                pen.lineTo((x * UNIT, y1))
                pen.lineTo((x * UNIT, y0))
                pen.closePath()
            else:
                x += 1
    return pen.glyph()


def build(src, out):
    width, height, glyphs, cmap = read_psf(src)
    names = [".notdef"] + [f"g{i}" for i in range(len(glyphs))]
    fb = FontBuilder(height * UNIT, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({cp: f"g{g}" for cp, g in cmap.items() if g < len(glyphs)})
    outlines = {".notdef": TTGlyphPen(None).glyph()}
    outlines.update({f"g{i}": outline(rows, width, height) for i, rows in enumerate(glyphs)})
    fb.setupGlyf(outlines)
    adv = width * UNIT
    fb.setupHorizontalMetrics({n: (adv, 0) for n in names})
    # The whole cell is ascent: line height = glyph height, no gaps between rows (like the tty).
    fb.setupHorizontalHeader(ascent=height * UNIT, descent=0)
    fb.setupNameTable({"familyName": FAMILY, "styleName": "Regular",
                       "version": f"Version 1.0; from {os.path.basename(src)}"})
    panose = Panose()
    panose.bFamilyType, panose.bProportion = 2, 9  # 9 = monospaced
    fb.setupOS2(sTypoAscender=height * UNIT, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=height * UNIT, usWinDescent=0, xAvgCharWidth=adv,
                panose=panose)
    # underline (and foot's underline cursor) on the bottom two pixel rows, like the console's cursor
    fb.setupPost(isFixedPitch=1, underlinePosition=UNIT, underlineThickness=2 * UNIT)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    fb.save(out)
    return width, height


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else console_font()
    out = sys.argv[2] if len(sys.argv) > 2 else OUT
    w, h = build(find(name), out)
    print(f"{out}: {FAMILY}, {w}x{h} from {name} (foot: font={FAMILY}:pixelsize={h})")
