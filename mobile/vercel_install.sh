#!/usr/bin/env bash
set -euo pipefail
if [ ! -d .flutter ]; then git clone --depth 1 -b stable https://github.com/flutter/flutter.git .flutter; fi
.flutter/bin/flutter config --no-analytics --enable-web
.flutter/bin/flutter precache --web
