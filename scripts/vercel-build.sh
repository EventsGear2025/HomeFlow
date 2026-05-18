#!/usr/bin/env bash

set -euo pipefail

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
else
  FLUTTER_ROOT="${VERCEL_FLUTTER_ROOT:-$HOME/flutter}"
  if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
    git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_ROOT"
  fi
  export PATH="$FLUTTER_ROOT/bin:$PATH"
  FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
fi

"$FLUTTER_BIN" config --enable-web
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build web