#!/usr/bin/env bash
# Runs the same checks as CI's first job. Run from anywhere; exits non-zero
# on the first failure. Use before every push.
set -euo pipefail
cd "$(dirname "$0")/.."

# Cloud sessions install Flutter outside PATH.
if ! command -v flutter >/dev/null 2>&1 && [ -x /opt/flutter/bin/flutter ]; then
  export PATH="/opt/flutter/bin:$PATH"
fi

flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
echo "All checks passed."
