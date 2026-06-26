#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
  flutter precache --web
fi

echo "Flutter version:"
flutter --version

flutter pub get
flutter build web --release --base-href / --dart-define=API_BASE_URL="${API_BASE_URL:-}"
