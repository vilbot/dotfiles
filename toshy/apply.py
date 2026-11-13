#!/usr/bin/env python3
"""Write this repo's Toshy customizations into an installed Toshy (Linux, Python 3.11+).

    python3 toshy/apply.py            # apply, restart Toshy if anything changed
    python3 toshy/apply.py --check    # exit 1 if the installed Toshy differs (writes nothing)

Toshy's installer regenerates ~/.config/toshy/toshy_config.py on upgrade, keeping only the
"slices" between SLICE_MARK_START/END markers. So the repo holds just those parts:
    toshy/slices/<slice name>.py   <- replaces that slice's body in toshy_config.py
    toshy/preferences.toml         <- tray-menu settings, written into the preferences sqlite
To customize another slice, copy its body (between the marker lines) into slices/<name>.py.
"""
import pathlib, re, sqlite3, subprocess, sys, tomllib

REPO = pathlib.Path(__file__).resolve().parent
TOSHY = pathlib.Path.home() / ".config/toshy"
CONFIG = TOSHY / "toshy_config.py"
PREFS_DB = TOSHY / "toshy_user_preferences.sqlite"

if not CONFIG.exists():
    sys.exit(f"{CONFIG} not found; install Toshy first: https://github.com/RedBearAK/toshy")

check = "--check" in sys.argv
changed = []

# ---- config slices ------------------------------------------------------------------------
cfg = old_cfg = CONFIG.read_text()
for path in sorted((REPO / "slices").glob("*.py")):
    name = path.stem
    pat = re.compile(rf"(###  SLICE_MARK_START: {name}  ###[^\n]*\n)(.*?)(###  SLICE_MARK_END: {name}  ###)", re.S)
    assert len(pat.findall(cfg)) == 1, f"slice '{name}' not found exactly once in {CONFIG}"
    new = pat.sub(lambda m: m.group(1) + path.read_text() + m.group(3), cfg)
    if new != cfg:
        changed.append(f"slice {name}")
        cfg = new
if cfg != old_cfg and not check:
    CONFIG.write_text(cfg)

# ---- preferences --------------------------------------------------------------------------
prefs = tomllib.loads((REPO / "preferences.toml").read_text())
db = sqlite3.connect(PREFS_DB)
current = dict(db.execute("select name, value from config_preferences"))
for name, value in prefs.items():
    if current.get(name) != str(value):
        changed.append(f"pref {name}: {current.get(name)} -> {value}")
        if not check:
            db.execute("insert or replace into config_preferences (name, value) values (?, ?)", (name, str(value)))
db.commit()
db.close()

# ---- report -------------------------------------------------------------------------------
for c in changed:
    print(("differs " if check else "set     ") + c)
if check:
    sys.exit(1 if changed else 0)
if changed:
    subprocess.run(["systemctl", "--user", "restart", "toshy-config.service"], check=False)
    print("restarted toshy-config.service")
else:
    print("toshy up to date")
