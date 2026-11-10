#!/bin/sh
# Re-apply gruver16 tweaks to Zed's Java extension queries (extension updates overwrite them).
# Idempotent; triggered by launchd (com.vilgot.zed-java-patch) when the extension changes.
f="$HOME/Library/Application Support/Zed/extensions/installed/java/languages/java/highlights.scm"
[ -f "$f" ] || exit 0
grep -q 'gruver16-patched' "$f" && exit 0
perl -0pi -e '
  s/^\(this\) \@variable$/(this) \@keyword/m;
  s/("\@" \@punctuation\.special\n\s*name: \(identifier\) \@attribute)\)/$1.annotation)/g;
  s/^\s*\(void_type\)\n//m;
  $_ .= "\n(void_type) \@keyword\n; gruver16-patched\n";
' "$f"
