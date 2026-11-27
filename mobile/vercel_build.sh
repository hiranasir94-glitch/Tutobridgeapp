#!/usr/bin/env bash
set -euo pipefail
# The repo has no web/ folder yet, so generate the platform files on the build machine.
[ -d web ] || .flutter/bin/flutter create . --platforms=web --project-name tutobridge --org io.tutobridge
# Brand icons for the browser tab and home-screen shortcut.
cp web_icons/favicon.png web/favicon.png
cp web_icons/Icon-192.png web_icons/Icon-512.png web_icons/Icon-maskable-192.png web_icons/Icon-maskable-512.png web/icons/
sed -i 's#<title>[^<]*</title>#<title>Tutobridge</title>#' web/index.html
.flutter/bin/flutter pub get
.flutter/bin/flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://kdgyxgytcphnmsnvxdiz.supabase.co}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_5mo3bWfClhII0ymU2asdDg_Shpsc6fh}"
