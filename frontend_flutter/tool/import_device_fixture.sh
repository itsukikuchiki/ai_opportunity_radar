#!/usr/bin/env bash
set -euo pipefail

umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FIXTURE_DIR="${PROJECT_DIR}/test/fixtures/device_accounts"
BACKUP_ROOT="${FIXTURE_IMPORT_BACKUP_ROOT:-${PROJECT_DIR}/build/device_fixture_backups}"
DATABASE_NAME="ai_opportunity_radar_local.db"
BUNDLE_ID="${SIGNALPATH_BUNDLE_ID:-jp.sunrise.signalpath}"
XCRUN_BIN="${XCRUN_BIN:-xcrun}"
IOS_DEPLOY_BIN="${IOS_DEPLOY_BIN:-ios-deploy}"
SQLITE3_BIN="${SQLITE3_BIN:-}"

TARGET_KIND="simulator"
TARGET_ID="booted"
DEVICE_METHOD="auto"
ACCOUNT=""
DRY_RUN=false
LAUNCH=false
DEVICE_APP_STOPPED=false

readonly ACCOUNTS=(
  fresh_user
  legacy_user
  heavy_user
  offline_user
  experiment_user
  privacy_user
)

usage() {
  cat <<'USAGE'
Import one generated SignalPath QA database into an installed iOS app.

Usage:
  tool/import_device_fixture.sh ACCOUNT [--simulator booted|UDID] [--launch]
  tool/import_device_fixture.sh ACCOUNT --device UDID [--device-method auto|ios-deploy|devicectl-plan]
  tool/import_device_fixture.sh --list

Accounts:
  fresh_user legacy_user heavy_user offline_user experiment_user privacy_user

Options:
  --simulator ID          Import into a Simulator (default: booted).
  --device UDID           Import into a connected physical device.
  --device-method METHOD  auto, ios-deploy, or devicectl-plan (default: auto).
  --device-app-stopped    Physical device only: assert you already force-quit
                          the app if ios-deploy cannot terminate it.
  --bundle-id ID          Override jp.sunrise.signalpath.
  --launch                Launch after a verified import.
  --dry-run               Validate the fixture and print the plan; do not write.
  --list                  List the six fixture accounts.
  -h, --help              Show this help.

Safety:
  - The app must already be installed once so its data container exists.
  - The current database and SQLite sidecars are backed up before replacement.
  - Backups may contain private QA data and are written under build/ with 0700
    permissions unless FIXTURE_IMPORT_BACKUP_ROOT overrides the location.
  - A physical-device success is printed only after the copied DB is downloaded
    again and compared byte-for-byte. devicectl-plan never writes or reports
    success because devicectl alone cannot safely delete SQLite sidecars.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf 'ERROR: %s\n\n' "$*" >&2
  usage >&2
  exit 2
}

print_accounts() {
  printf '%s\n' "${ACCOUNTS[@]}"
}

require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "${value}" ]] || usage_error "${option} requires a value."
}

is_known_account() {
  local candidate="$1"
  local account
  for account in "${ACCOUNTS[@]}"; do
    [[ "${candidate}" == "${account}" ]] && return 0
  done
  return 1
}

print_command() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
}

safe_component() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
}

new_backup_dir() {
  local target_label="$1"
  local stamp
  stamp="$(date -u '+%Y%m%d-%H%M%S')-$$"
  local path="${BACKUP_ROOT}/$(safe_component "${target_label}")/${stamp}-${ACCOUNT}"
  mkdir -p "${path}"
  printf '%s\n' "${path}"
}

discover_sqlite3() {
  if [[ -n "${SQLITE3_BIN}" ]]; then
    [[ -x "${SQLITE3_BIN}" ]] || die "SQLITE3_BIN is not executable: ${SQLITE3_BIN}"
    return
  fi
  if command -v sqlite3 >/dev/null 2>&1; then
    SQLITE3_BIN="$(command -v sqlite3)"
  fi
}

validate_database() {
  local path="$1"
  local label="$2"
  [[ -f "${path}" ]] || die "${label} does not exist: ${path}"

  local magic
  magic="$(LC_ALL=C head -c 15 "${path}")"
  [[ "${magic}" == "SQLite format 3" ]] || die "${label} is not a SQLite 3 database: ${path}"

  discover_sqlite3
  if [[ -z "${SQLITE3_BIN}" ]]; then
    printf 'WARNING: sqlite3 was not found; %s passed header validation only.\n' "${label}" >&2
    return
  fi

  local check
  check="$("${SQLITE3_BIN}" "${path}" 'PRAGMA quick_check;' | tr -d '\r')"
  [[ "${check}" == "ok" ]] || die "${label} failed SQLite quick_check: ${check}"
}

write_backup_note() {
  local backup_dir="$1"
  local target="$2"
  {
    printf 'fixture=%s\n' "${ACCOUNT}"
    printf 'source=%s\n' "${FIXTURE_PATH}"
    printf 'target=%s\n' "${target}"
    printf 'bundle_id=%s\n' "${BUNDLE_ID}"
    printf 'created_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } > "${backup_dir}/import.txt"
}

backup_local_database_files() {
  local destination="$1"
  local backup_dir="$2"
  local suffix
  for suffix in '' '-wal' '-shm' '-journal'; do
    if [[ -f "${destination}${suffix}" ]]; then
      cp -p "${destination}${suffix}" "${backup_dir}/${DATABASE_NAME}${suffix}"
    fi
  done
}

quick_check_imported_copy() {
  local path="$1"
  validate_database "${path}" 'imported database'
  cmp -s "${FIXTURE_PATH}" "${path}" || die "Imported database differs from fixture bytes."
}

import_simulator() {
  if [[ "${DRY_RUN}" == true ]]; then
    printf 'DRY RUN: would import %s into Simulator %s (%s).\n' "${ACCOUNT}" "${TARGET_ID}" "${BUNDLE_ID}"
    printf 'The app would be terminated, its current DB/sidecars backed up, and the fixture atomically installed.\n'
    return
  fi

  command -v "${XCRUN_BIN}" >/dev/null 2>&1 || die "xcrun is required for Simulator import."

  local container
  if ! container="$("${XCRUN_BIN}" simctl get_app_container "${TARGET_ID}" "${BUNDLE_ID}" data 2>/dev/null)"; then
    die "Could not resolve the app data container. Boot the Simulator and install ${BUNDLE_ID} once before importing."
  fi
  [[ -d "${container}" ]] || die "Simulator returned a missing data container: ${container}"

  local terminate_output=''
  if ! terminate_output="$("${XCRUN_BIN}" simctl terminate "${TARGET_ID}" "${BUNDLE_ID}" 2>&1)"; then
    local normalized_terminate_output
    normalized_terminate_output="$(printf '%s' "${terminate_output}" | tr '[:upper:]' '[:lower:]')"
    if [[ "${normalized_terminate_output}" != *'not running'* &&
          "${normalized_terminate_output}" != *'nothing to terminate'* ]]; then
      die "Could not safely terminate the Simulator app. No database write was performed: ${terminate_output}"
    fi
  fi

  local documents="${container}/Documents"
  [[ -d "${documents}" ]] || die "App Documents directory is missing: ${documents}"
  local destination="${documents}/${DATABASE_NAME}"
  local backup_dir
  backup_dir="$(new_backup_dir "simulator-${TARGET_ID}")"
  backup_local_database_files "${destination}" "${backup_dir}"
  write_backup_note "${backup_dir}" "simulator:${TARGET_ID}:${destination}"

  local incoming="${documents}/.${DATABASE_NAME}.fixture-import.$$"
  cp "${FIXTURE_PATH}" "${incoming}"
  chmod 600 "${incoming}"
  rm -f "${destination}-wal" "${destination}-shm" "${destination}-journal"
  mv -f "${incoming}" "${destination}"

  quick_check_imported_copy "${destination}"
  printf 'Imported and verified %s in Simulator %s.\n' "${ACCOUNT}" "${TARGET_ID}"
  printf 'Backup: %s\n' "${backup_dir}"

  if [[ "${LAUNCH}" == true ]]; then
    "${XCRUN_BIN}" simctl launch "${TARGET_ID}" "${BUNDLE_ID}" >/dev/null
    printf 'Launched %s. The app may now migrate fixture schema v32 to the current local schema.\n' "${BUNDLE_ID}"
  else
    printf 'Next: launch the app manually; first launch migrates fixture schema v32 to the current local schema.\n'
  fi
}

find_downloaded_file() {
  local root="$1"
  local name="$2"
  find "${root}" -type f -name "${name}" -print -quit
}

print_devicectl_plan() {
  local backup_dir="$1"
  printf 'NO DEVICE WRITE WAS PERFORMED.\n' >&2
  printf 'devicectl can copy app-container files, but this tool cannot use it alone to safely terminate the app and delete stale SQLite sidecars.\n' >&2
  printf 'Force-quit Signal Path, then use the following as an inspected manual path (or install ios-deploy and rerun):\n' >&2
  print_command "${XCRUN_BIN}" devicectl device copy from \
    --device "${TARGET_ID}" \
    --source Documents \
    --destination "${backup_dir}" \
    --domain-type appDataContainer \
    --domain-identifier "${BUNDLE_ID}" >&2
  printf 'Inspect the backup for %s-wal / -shm / -journal. If any exist, do not overwrite with devicectl alone; use ios-deploy cleanup.\n' "${DATABASE_NAME}" >&2
  print_command "${XCRUN_BIN}" devicectl device copy to \
    --device "${TARGET_ID}" \
    --source "${FIXTURE_PATH}" \
    --destination "Documents/${DATABASE_NAME}" \
    --domain-type appDataContainer \
    --domain-identifier "${BUNDLE_ID}" >&2
}

device_remove_if_backed_up() {
  local backup_documents="$1"
  local file_name="$2"
  if [[ -n "$(find_downloaded_file "${backup_documents}" "${file_name}")" ]]; then
    "${IOS_DEPLOY_BIN}" -i "${TARGET_ID}" --bundle_id "${BUNDLE_ID}" \
      --rm "/Documents/${file_name}" >/dev/null
  fi
}

import_device_with_ios_deploy() {
  command -v "${IOS_DEPLOY_BIN}" >/dev/null 2>&1 || die "ios-deploy is not installed."

  if [[ "${DRY_RUN}" == true ]]; then
    printf 'DRY RUN: would import %s into physical device %s with ios-deploy.\n' "${ACCOUNT}" "${TARGET_ID}"
    printf 'The app would be stopped, Documents backed up, DB/sidecars replaced, and the DB downloaded for byte verification.\n'
    return
  fi

  "${IOS_DEPLOY_BIN}" -i "${TARGET_ID}" --bundle_id "${BUNDLE_ID}" --exists >/dev/null \
    || die "${BUNDLE_ID} is not installed or the physical device is unavailable. No write was performed."

  if [[ "${DEVICE_APP_STOPPED}" != true ]]; then
    if ! "${IOS_DEPLOY_BIN}" -i "${TARGET_ID}" --bundle_id "${BUNDLE_ID}" --kill >/dev/null 2>&1; then
      die "Could not confirm that Signal Path stopped. Force-quit it and rerun with --device-app-stopped. No write was performed."
    fi
  fi

  local backup_dir
  backup_dir="$(new_backup_dir "device-${TARGET_ID}")"
  local backup_documents="${backup_dir}/documents-before"
  mkdir -p "${backup_documents}"
  if ! "${IOS_DEPLOY_BIN}" -i "${TARGET_ID}" --bundle_id "${BUNDLE_ID}" \
      --download=/Documents --to "${backup_documents}" >/dev/null; then
    die "Could not back up the physical-device Documents directory. No database write was attempted."
  fi
  write_backup_note "${backup_dir}" "device:${TARGET_ID}:Documents/${DATABASE_NAME}"

  local suffix
  for suffix in '' '-wal' '-shm' '-journal'; do
    device_remove_if_backed_up "${backup_documents}" "${DATABASE_NAME}${suffix}"
  done

  if ! "${IOS_DEPLOY_BIN}" -i "${TARGET_ID}" --bundle_id "${BUNDLE_ID}" \
      --upload "${FIXTURE_PATH}" --to "Documents/${DATABASE_NAME}" >/dev/null; then
    die "Physical-device upload failed after backup. Import is NOT verified. Restore from ${backup_documents} before launching the app."
  fi

  local verify_documents="${backup_dir}/documents-after"
  mkdir -p "${verify_documents}"
  if ! "${IOS_DEPLOY_BIN}" -i "${TARGET_ID}" --bundle_id "${BUNDLE_ID}" \
      --download=/Documents --to "${verify_documents}" >/dev/null; then
    die "Upload returned but read-back failed. Import is NOT verified; do not launch the app. Backup: ${backup_dir}"
  fi

  local downloaded
  downloaded="$(find_downloaded_file "${verify_documents}" "${DATABASE_NAME}")"
  [[ -n "${downloaded}" ]] || die "Read-back did not contain ${DATABASE_NAME}; import is NOT verified."
  quick_check_imported_copy "${downloaded}"
  for suffix in '-wal' '-shm' '-journal'; do
    [[ -z "$(find_downloaded_file "${verify_documents}" "${DATABASE_NAME}${suffix}")" ]] \
      || die "Stale SQLite sidecar remains on device (${DATABASE_NAME}${suffix}); import is NOT safe to launch."
  done

  printf 'Imported and verified %s on physical device %s.\n' "${ACCOUNT}" "${TARGET_ID}"
  printf 'Backup and read-back evidence: %s\n' "${backup_dir}"

  if [[ "${LAUNCH}" == true ]]; then
    if "${XCRUN_BIN}" devicectl device process launch --device "${TARGET_ID}" \
        --terminate-existing "${BUNDLE_ID}" >/dev/null; then
      printf 'Launched %s. The app may now migrate fixture schema v32 to the current local schema.\n' "${BUNDLE_ID}"
    else
      printf 'WARNING: import is verified, but automatic launch failed. Open Signal Path manually.\n' >&2
      exit 4
    fi
  else
    printf 'Next: open Signal Path manually; first launch migrates fixture schema v32 to the current local schema.\n'
  fi
}

import_physical_device() {
  local method="${DEVICE_METHOD}"
  if [[ "${method}" == auto ]]; then
    if command -v "${IOS_DEPLOY_BIN}" >/dev/null 2>&1; then
      method="ios-deploy"
    else
      method="devicectl-plan"
    fi
  fi

  case "${method}" in
    ios-deploy)
      import_device_with_ios_deploy
      ;;
    devicectl-plan)
      local backup_dir="${BACKUP_ROOT}/device-$(safe_component "${TARGET_ID}")/devicectl-manual-backup"
      print_devicectl_plan "${backup_dir}"
      if [[ "${DRY_RUN}" == true ]]; then
        return
      fi
      exit 3
      ;;
    *)
      usage_error "Unknown --device-method: ${method}"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --simulator)
      require_value "$1" "${2:-}"
      TARGET_KIND="simulator"
      TARGET_ID="$2"
      shift 2
      ;;
    --device)
      require_value "$1" "${2:-}"
      TARGET_KIND="device"
      TARGET_ID="$2"
      shift 2
      ;;
    --device-method)
      require_value "$1" "${2:-}"
      DEVICE_METHOD="$2"
      shift 2
      ;;
    --device-app-stopped)
      DEVICE_APP_STOPPED=true
      shift
      ;;
    --bundle-id)
      require_value "$1" "${2:-}"
      BUNDLE_ID="$2"
      shift 2
      ;;
    --launch)
      LAUNCH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --list)
      print_accounts
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      usage_error "Unknown option: $1"
      ;;
    *)
      [[ -z "${ACCOUNT}" ]] || usage_error "Only one fixture account can be imported at a time."
      ACCOUNT="$1"
      shift
      ;;
  esac
done

[[ -n "${ACCOUNT}" ]] || usage_error 'Choose one fixture account or use --list.'
is_known_account "${ACCOUNT}" || usage_error "Unknown fixture account: ${ACCOUNT}"
[[ -n "${TARGET_ID}" ]] || usage_error 'Target ID must not be empty.'
[[ "${TARGET_KIND}" == device || "${DEVICE_METHOD}" == auto ]] \
  || usage_error '--device-method is valid only with --device.'
[[ "${TARGET_KIND}" == device || "${DEVICE_APP_STOPPED}" == false ]] \
  || usage_error '--device-app-stopped is valid only with --device.'

FIXTURE_PATH="${FIXTURE_DIR}/${ACCOUNT}.db"
validate_database "${FIXTURE_PATH}" "fixture ${ACCOUNT}"

case "${TARGET_KIND}" in
  simulator) import_simulator ;;
  device) import_physical_device ;;
  *) usage_error "Unknown target kind: ${TARGET_KIND}" ;;
esac
