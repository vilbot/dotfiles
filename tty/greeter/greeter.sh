#!/usr/bin/env bash
# greetd's greeter: the None-looking login screen (greeter.lua). If it ends without anyone
# having logged in (it failed to start, or crashed), the plain text login screen takes over,
# so you can always get in.
here=/etc/greetd/none
# the greeter user's home is / (not writable): Hyprland and Quickshell write their caches here
export HOME=/var/cache/none-greeter/home
export XDG_CACHE_HOME=$HOME/.cache XDG_STATE_HOME=$HOME/.local/state XDG_DATA_HOME=$HOME/.local/share
done=${XDG_RUNTIME_DIR:-/tmp}/none-greeter-done
rm -f "$done"
start-hyprland -- -c "$here/greeter.lua" >"$HOME/hyprland.log" 2>&1   # read: sudo cat /var/cache/none-greeter/home/hyprland.log
[[ -e $done ]] && exit 0
exec tuigreet --time --asterisks --remember --remember-user-session --sessions /etc/greetd/sessions
