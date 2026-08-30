#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "download_model.sh" "05_model_download"
require_root
require_value MODEL_URL
require_value MODEL_SHA256
require_value MODEL_PATH
new_evidence_dir model-download

mkdir -p "${MODEL_DIR}"
partial="${MODEL_PATH}.partial"
rm -f "${partial}"
curl --fail --location --retry 3 --output "${partial}" "${MODEL_URL}"
printf '%s  %s\n' "${MODEL_SHA256}" "${partial}" | sha256sum -c -
mv -f "${partial}" "${MODEL_PATH}"
chmod 0644 "${MODEL_PATH}"
sha256sum "${MODEL_PATH}" > "${EVIDENCE_DIR}/model.sha256"
printf 'model_id=%s\nmodel_repo=%s\nmodel_file=%s\n' \
  "${MODEL_ID}" "${MODEL_GGUF_REPO}" "${MODEL_FILE}" > "${EVIDENCE_DIR}/model-reference.txt"
write_result PASS 'Gemma 4 E2B GGUF downloaded and verified against the operator-provided SHA256.'
mark_state 05_model_download.pass
finish_script PASS '05_llm_server.sh'
