#!/usr/bin/env bash
set -euo pipefail

# Cloudflare Pages build command for this Flutter web application.
FLUTTER_HOME="${HOME}/flutter"

if [[ ! -d "${FLUTTER_HOME}/.git" ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"

# Base URL of the Worker API. Public, not a secret, so it has a working default;
# override it with a WEA_API_BASE_URL environment variable in the Pages project
# to point a build at a different API. Without this the app falls back to its
# offline development backend and nothing persists.
WEA_API_BASE_URL="${WEA_API_BASE_URL:-https://wuco-api.dawillcomputers.workers.dev}"

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=WEA_API_BASE_URL="${WEA_API_BASE_URL}"
