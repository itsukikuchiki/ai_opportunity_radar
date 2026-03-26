#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../frontend_flutter"
flutter pub get
flutter run -d chrome
