#!/usr/bin/env python3
"""Exit as soon as no Alt key is held (used by quickshell/AppSwitcher.qml).

Letting go of Cmd ends the Cmd+Tab switcher. Toshy sends Cmd as a held Alt, but neither Hyprland
release binds (skipped after Tab was pressed) nor the switcher window (it never saw Alt go down)
reliably see Alt being let go. So read which keys are down straight from the kernel (EVIOCGKEY)
on Toshy's virtual keyboard, plus any other keyboard, every 15 ms. Needs the `input` group.
Exits after 60 s regardless.
"""
import array
import fcntl
import os
import re
import sys
import time

KEY_LEFTALT, KEY_RIGHTALT = 56, 100
KEY_MAX = 0x2FF
NBYTES = KEY_MAX // 8 + 1
EVIOCGKEY = (2 << 30) | (NBYTES << 16) | (ord("E") << 8) | 0x18


def keyboards():
    """/dev/input/eventN of every device with the kbd handler."""
    text = open("/proc/bus/input/devices").read()
    for block in text.split("\n\n"):
        handlers = re.search(r"^H: Handlers=(.*)$", block, re.M)
        if handlers and "kbd" in handlers.group(1).split():
            ev = re.search(r"\bevent\d+\b", handlers.group(1))
            if ev:
                yield "/dev/input/" + ev.group(0)


fds = []
for path in keyboards():
    try:
        fds.append(os.open(path, os.O_RDONLY | os.O_NONBLOCK))
    except OSError:
        pass
if not fds:
    sys.exit(1)

buf = array.array("B", [0] * NBYTES)
deadline = time.monotonic() + 60
while time.monotonic() < deadline:
    held = False
    for fd in fds:
        try:
            fcntl.ioctl(fd, EVIOCGKEY, buf, True)
        except OSError:
            continue
        if any(buf[k // 8] & (1 << (k % 8)) for k in (KEY_LEFTALT, KEY_RIGHTALT)):
            held = True
            break
    if not held:
        sys.exit(0)
    time.sleep(0.015)
