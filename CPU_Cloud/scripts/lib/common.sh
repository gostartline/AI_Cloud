#!/usr/bin/env bash
set -Eeuo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPTS_ROOT="$(cd "${COMMON_DIR}/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${COMMON_SCRIPTS_ROOT}/../config.env}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  printf '[FAIL] Missing %s. Copy config.env.example to config.env first.\n' "${CONFIG_FILE}" >&2
  exit 2
fi
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

STARTLINE_LOG_DIR="${STARTLINE_ORCHESTRATOR_LOG_DIR:-${STARTLINE_LOG_DIR:-/var/log/startline-cpu-cloud}}"
STARTLINE_STATE_DIR="${STARTLINE_ORCHESTRATOR_STATE_DIR:-${STARTLINE_STATE_DIR:-/var/lib/startline-cpu-cloud}}"
EVIDENCE_ROOT="${STARTLINE_ORCHESTRATOR_EVIDENCE_ROOT:-${EVIDENCE_ROOT:-${STARTLINE_STATE_DIR}/evidence}}"
mkdir -p "${STARTLINE_LOG_DIR}" "${STARTLINE_STATE_DIR}" "${EVIDENCE_ROOT}"

log() { printf '[%s] %s\n' "$1" "$2"; }
info() { log INFO "$*"; }
warn() { log WARN "$*"; }
pass() { log PASS "$*"; }
fail() { log FAIL "$*" >&2; return 1; }

require_root() { [[ "${EUID}" -eq 0 ]] || fail 'Run as root.'; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
require_value() {
  local name="$1" value="${!1:-}"
  [[ -n "${value}" && "${value}" != REQUIRED* ]] || fail "Required config value is not pinned: ${name}"
}
resolve_apt_package_version() {
  local package="$1" version="$2"
  apt-cache madison "${package}" |
    awk -v v="${version}" '
      $3 ~ "^" v "-" && !found {
        result=$3
        found=1
      }
      END {
        if (found) print result
      }
    '
}
assert_ge() {
  local actual="$1" expected="$2" label="$3"
  [[ "${actual}" -ge "${expected}" ]] || fail "${label}=${actual} is below required ${expected}"
}
state_file() { printf '%s/%s' "${STARTLINE_STATE_DIR}" "$1"; }
mark_state() {
  local marker="$1" base="${1%.*}"
  rm -f "$(state_file "${base}.pass")" "$(state_file "${base}.incomplete")" "$(state_file "${base}.fail")"
  printf '%s\n' "$(date -u +%FT%TZ)" > "$(state_file "${marker}")"
}
has_state() { [[ -f "$(state_file "$1")" ]]; }

on_error() {
  local rc=$? line=${BASH_LINENO[0]:-unknown}
  if [[ -n "${STATE_NAME:-}" ]]; then mark_state "${STATE_NAME}.fail"; fi
  log FAIL "${SCRIPT_NAME:-script} failed at line ${line} (rc=${rc})" >&2
  exit "${rc}"
}
trap on_error ERR

start_script() {
  SCRIPT_NAME="${1:-$(basename "$0")}"; export SCRIPT_NAME
  STATE_NAME="${2:-}"; export STATE_NAME
  SCRIPT_START="$(date -u +%FT%TZ)"; export SCRIPT_START
  LOG_FILE="${STARTLINE_LOG_DIR}/${SCRIPT_NAME%.sh}.log"; export LOG_FILE
  mkdir -p "$(dirname "${LOG_FILE}")"
  exec > >(tee -a "${LOG_FILE}") 2>&1
  info "Start ${SCRIPT_NAME} baseline=${BASELINE_VERSION:-unknown}"
}

finish_script() {
  local result="${1:-PASS}" next="${2:-none}"
  printf '\nScript: %s\nHost: %s\nStart: %s\nEnd: %s\nResult: %s\nLog: %s\nNext: %s\n' \
    "${SCRIPT_NAME}" "$(hostname -s)" "${SCRIPT_START}" "$(date -u +%FT%TZ)" \
    "${result}" "${LOG_FILE}" "${next}"
}
