#!/usr/bin/env bash
set -euo pipefail

# Cloudflare Pages build command for this Flutter web application.
FLUTTER_HOME="${HOME}/flutter"

if [[ ! -d "${FLUTTER_HOME}/.git" ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"
flutter config --enable-web
flutter pub get
flutter build web --release
