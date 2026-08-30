#!/usr/bin/env bash
set -Eeuo pipefail

evidence_utc_now() { date -u +%FT%TZ; }

new_evidence_dir() {
  local phase="$1" stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_DIR="${EVIDENCE_ROOT}/${phase}/${stamp}"
  if [[ -e "${EVIDENCE_DIR}" ]]; then
    EVIDENCE_DIR="${EVIDENCE_ROOT}/${phase}/${stamp}-$$"
  fi
  mkdir -p "${EVIDENCE_DIR}"
  export EVIDENCE_DIR
}

capture() {
  local name="$1"; shift
  [[ -n "${EVIDENCE_DIR:-}" ]] || fail 'EVIDENCE_DIR is not initialized'
  printf '%q ' "$@" > "${EVIDENCE_DIR}/${name}.command.txt"
  printf '\n' >> "${EVIDENCE_DIR}/${name}.command.txt"
  "$@" > "${EVIDENCE_DIR}/${name}.stdout.txt" 2> "${EVIDENCE_DIR}/${name}.stderr.txt"
}

write_result() {
  local status="$1" note="${2:-}"
  cat > "${EVIDENCE_DIR}/result.md" <<EOF
# Validation Result

- Time (UTC): $(evidence_utc_now)
- Host: $(hostname -s)
- Script: ${SCRIPT_NAME:-unknown}
- Baseline: ${BASELINE_VERSION:-unknown}
- Result: ${status}
- Note: ${note}
EOF
}

evidence_state_status() {
  local pass_marker="$1" incomplete_marker="${2:-}" fail_marker="${3:-}"
  if [[ -n "${fail_marker}" && -f "${STARTLINE_STATE_DIR}/${fail_marker}" ]]; then
    printf 'FAIL'
  elif [[ -n "${incomplete_marker}" && -f "${STARTLINE_STATE_DIR}/${incomplete_marker}" ]]; then
    printf 'INCOMPLETE'
  elif [[ -f "${STARTLINE_STATE_DIR}/${pass_marker}" ]]; then
    printf 'PASS'
  else
    printf 'NOT_RUN'
  fi
}

evidence_overall_status() {
  local status
  for status in "$@"; do
    [[ "${status}" != FAIL ]] || { printf 'FAIL'; return 0; }
  done
  for status in "$@"; do
    [[ "${status}" != INCOMPLETE && "${status}" != NOT_RUN ]] || { printf 'INCOMPLETE'; return 0; }
  done
  printf 'PASS'
}

sanitize_text_file() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  sed -E -i \
    -e 's/(Bearer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/((token|password|secret|authorization|api[_-]?key|private[_-]?key|cookie|credential)[[:space:]]*[=:][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/([A-Za-z0-9_-]{10,}\.){2}[A-Za-z0-9_-]{10,}/[JWT_REDACTED]/g' \
    -e 's/([a-z0-9]{6}\.[a-z0-9]{16})/[KUBEADM_TOKEN_REDACTED]/g' \
    -e 's/([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}/[MAC_REDACTED]/g' \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IP_REDACTED]/g' \
    "${file}"
}

sanitize_public_tree() {
  local root="$1" file
  [[ -d "${root}" ]] || return 0
  find "${root}" -type f \( \
    -name '*kubeconfig*' -o -name '*admin.conf*' -o -name '*.pem' -o -name '*.key' -o \
    -name '*token*' -o -name '*secret*' -o -name 'config.env' -o -name '*.runtime' \
  \) -delete
  while IFS= read -r -d '' file; do sanitize_text_file "${file}"; done < <(
    find "${root}" -type f \( -name '*.txt' -o -name '*.log' -o -name '*.md' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) -print0
  )
}

write_sha256_manifest() {
  local root="$1" manifest="${2:-MANIFEST.sha256}"
  (cd "${root}" && find . -type f ! -name "${manifest}" -print0 | sort -z | xargs -0 -r sha256sum > "${manifest}")
}

verify_sha256_manifest() {
  local root="$1" manifest="${2:-MANIFEST.sha256}"
  (cd "${root}" && sha256sum -c "${manifest}")
}
