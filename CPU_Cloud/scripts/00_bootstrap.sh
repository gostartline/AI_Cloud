#!/usr/bin/env bash
set -Eeuo pipefail

# Minimal host bootstrap for a clean Ubuntu VM.
# This script intentionally does not depend on scripts/lib/common.sh because
# its job is to install the commands that later validation scripts require.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config.env}"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

STARTLINE_LOG_DIR="${STARTLINE_ORCHESTRATOR_LOG_DIR:-${STARTLINE_LOG_DIR:-/var/log/startline-cpu-cloud}}"
STARTLINE_STATE_DIR="${STARTLINE_ORCHESTRATOR_STATE_DIR:-${STARTLINE_STATE_DIR:-/var/lib/startline-cpu-cloud}}"
mkdir -p "${STARTLINE_LOG_DIR}" "${STARTLINE_STATE_DIR}"

BOOTSTRAP_PASS="${STARTLINE_STATE_DIR}/00_bootstrap.pass"
BOOTSTRAP_FAIL="${STARTLINE_STATE_DIR}/00_bootstrap.fail"
rm -f "${BOOTSTRAP_PASS}" "${BOOTSTRAP_FAIL}"

on_error() {
  local rc="${1:-$?}"
  printf '%s\n' "$(date -u +%FT%TZ)" > "${BOOTSTRAP_FAIL}" || true
  printf '[FAIL] Bootstrap failed (rc=%s).\n' "${rc}" >&2
  exit "${rc}"
}
trap on_error ERR

fail_bootstrap() {
  local message="$1" rc="${2:-1}"
  printf '[FAIL] %s\n' "${message}" >&2
  on_error "${rc}"
}

[[ "${EUID}" -eq 0 ]] || fail_bootstrap 'Run as root.'
command -v apt-get >/dev/null 2>&1 || fail_bootstrap 'apt-get is required.'

LOG_FILE="${STARTLINE_LOG_DIR}/00_bootstrap.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

printf '[INFO] Installing minimal CPU Cloud bootstrap packages.\n'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git gpg jq python3 iproute2 procps util-linux coreutils findutils gawk grep sed tar xz-utils

for cmd in curl git python3 ss ip free awk df jq sha256sum; do
  command -v "${cmd}" >/dev/null 2>&1 || fail_bootstrap "Bootstrap command is still unavailable: ${cmd}"
done

rm -f "${BOOTSTRAP_FAIL}"
printf '%s\n' "$(date -u +%FT%TZ)" > "${BOOTSTRAP_PASS}"
printf '[PASS] Minimal bootstrap completed. Next: 00_precheck.sh\n'
