#!/bin/sh
# Install (or with --uninstall, remove) the launch agent that re-applies
# java-highlights.sh whenever Zed's installed extensions change.
set -e
dir="$(cd "$(dirname "$0")" && pwd)"
label=com.vilgot.zed-java-patch
plist="$HOME/Library/LaunchAgents/$label.plist"
domain="gui/$(id -u)"

launchctl bootout "$domain/$label" 2>/dev/null || true

if [ "$1" = "--uninstall" ]; then
  rm -f "$plist"
  echo "removed $label (patched highlights stay until the next Java extension update)"
  exit 0
fi

chmod +x "$dir/java-highlights.sh"
mkdir -p "$HOME/Library/LaunchAgents"
ln -sf "$dir/$label.plist" "$plist"
launchctl bootstrap "$domain" "$plist"
echo "installed $label; restart Zed if it was open"
