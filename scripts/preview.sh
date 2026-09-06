#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v flutter >/dev/null 2>&1; then
  flutter_bin=flutter
elif [ -x .tools/flutter/bin/flutter ]; then
  flutter_bin=.tools/flutter/bin/flutter
else
  echo 'Flutter belum tersedia. Panduan: https://docs.flutter.dev/install/manual'
  exit 1
fi
"$flutter_bin" pub get
env_file="${YOUWELL_ENV_FILE:-config/env/development.json}"
if [ ! -f "$env_file" ]; then
  env_file="config/env/development.example.json"
fi
"$flutter_bin" build web --release --no-web-resources-cdn --pwa-strategy=none --dart-define-from-file="$env_file"
node scripts/serve.mjs
