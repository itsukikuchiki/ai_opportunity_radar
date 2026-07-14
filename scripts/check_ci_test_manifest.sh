#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/p2-1-ci-gates.yml"

flutter_inventory="$(mktemp)"
flutter_manifest="$(mktemp)"
backend_inventory="$(mktemp)"
backend_manifest="$(mktemp)"
trap 'rm -f "$flutter_inventory" "$flutter_manifest" "$backend_inventory" "$backend_manifest"' EXIT

find "$repo_root/frontend_flutter/test" -type f -name '*_test.dart' \
  | sed "s#^$repo_root/frontend_flutter/##" \
  | sort -u > "$flutter_inventory"
grep -oE 'test/[A-Za-z0-9_./-]+_test\.dart' "$workflow" \
  | sort -u > "$flutter_manifest"

find "$repo_root/backend/tests" -type f -name 'test_*.py' \
  | sed "s#^$repo_root/##" \
  | sort -u > "$backend_inventory"
grep -oE 'backend/tests/[A-Za-z0-9_./-]+\.py' "$workflow" \
  | sort -u > "$backend_manifest"

missing_flutter="$(comm -23 "$flutter_inventory" "$flutter_manifest")"
missing_backend="$(comm -23 "$backend_inventory" "$backend_manifest")"
stale_flutter="$(comm -13 "$flutter_inventory" "$flutter_manifest")"
stale_backend="$(comm -13 "$backend_inventory" "$backend_manifest")"

if [[ -n "$missing_flutter" || -n "$missing_backend" || \
      -n "$stale_flutter" || -n "$stale_backend" ]]; then
  [[ -z "$missing_flutter" ]] || printf 'Flutter tests missing from CI:\n%s\n' "$missing_flutter"
  [[ -z "$missing_backend" ]] || printf 'Backend tests missing from CI:\n%s\n' "$missing_backend"
  [[ -z "$stale_flutter" ]] || printf 'Stale Flutter CI test paths:\n%s\n' "$stale_flutter"
  [[ -z "$stale_backend" ]] || printf 'Stale backend CI test paths:\n%s\n' "$stale_backend"
  exit 1
fi

printf 'CI test manifest covers every Flutter and backend test file.\n'
