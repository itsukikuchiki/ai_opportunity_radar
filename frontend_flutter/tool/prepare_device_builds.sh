#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-print}"
STAGING_API_BASE_URL="${STAGING_API_BASE_URL:-https://aiopportunityradar-staging.up.railway.app}"
PRODUCTION_API_BASE_URL="${PRODUCTION_API_BASE_URL:-https://aiopportunityradar-production.up.railway.app}"

usage() {
  cat <<'USAGE'
Usage:
  tool/prepare_device_builds.sh print
  tool/prepare_device_builds.sh build

Environment overrides:
  STAGING_API_BASE_URL     API endpoint for staging/internal builds
  PRODUCTION_API_BASE_URL  API endpoint for release-like/production-like builds

Outputs:
  build/ios/archive/Runner.xcarchive
  build/ios/ipa/*.ipa

Notes:
  - This script does not upload to TestFlight/App Store Connect.
  - Internal enables Trace Debug, fallback counters, and pipeline log surfaces.
  - Release-like and production-like keep debug tools hidden.
USAGE
}

run_or_print() {
  local label="$1"
  shift
  echo
  echo "==> ${label}"
  printf '%q ' "$@"
  echo
  if [[ "${MODE}" == "build" ]]; then
    "$@"
  fi
}

if [[ "${MODE}" != "print" && "${MODE}" != "build" ]]; then
  usage
  exit 2
fi

run_or_print "Debug / Internal build" \
  flutter build ipa \
  --debug \
  --dart-define=SIGNALPATH_BUILD_PROFILE=internal \
  --dart-define=SIGNALPATH_ENABLE_DEBUG_TOOLS=true \
  --dart-define=SIGNALPATH_ENABLE_PIPELINE_LOGS=true \
  --dart-define=API_BASE_URL="${STAGING_API_BASE_URL}"

run_or_print "Release-like build" \
  flutter build ipa \
  --release \
  --dart-define=SIGNALPATH_BUILD_PROFILE=release-like \
  --dart-define=SIGNALPATH_ENABLE_DEBUG_TOOLS=false \
  --dart-define=SIGNALPATH_ENABLE_PIPELINE_LOGS=false \
  --dart-define=API_BASE_URL="${PRODUCTION_API_BASE_URL}"
run_or_print "Staging build" \
  flutter build ipa \
  --profile \
  --dart-define=SIGNALPATH_BUILD_PROFILE=staging \
  --dart-define=SIGNALPATH_ENABLE_DEBUG_TOOLS=true \
  --dart-define=SIGNALPATH_ENABLE_PIPELINE_LOGS=true \
  --dart-define=API_BASE_URL="${STAGING_API_BASE_URL}"

run_or_print "Production-like build" \
  flutter build ipa \
  --release \
  --dart-define=SIGNALPATH_BUILD_PROFILE=production-like \
  --dart-define=SIGNALPATH_ENABLE_DEBUG_TOOLS=false \
  --dart-define=SIGNALPATH_ENABLE_PIPELINE_LOGS=false \
  --dart-define=API_BASE_URL="${PRODUCTION_API_BASE_URL}"
