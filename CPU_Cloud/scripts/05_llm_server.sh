#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "05_llm_server.sh" "05_llm_server"
require_root
has_state 04_single_node_cluster.pass || fail 'Run 04_single_node_cluster.sh first.'
require_value MODEL_PATH
require_value MODEL_FILE
require_value MODEL_SHA256
require_value LLM_IMAGE
require_value LLM_NAMESPACE
require_value LLM_SERVICE
new_evidence_dir llm-server

[[ -f "${MODEL_PATH}" ]] || fail "Model file not found: ${MODEL_PATH}; run download_model.sh first."
actual_sha256="$(sha256sum "${MODEL_PATH}" | awk '{print $1}')"
[[ "${actual_sha256}" == "${MODEL_SHA256}" ]] ||
  fail "Model SHA256 mismatch: expected=${MODEL_SHA256} actual=${actual_sha256}"
printf 'model_path=%s\nmodel_sha256=%s\nmodel_size_bytes=%s\n' \
  "${MODEL_PATH}" "${actual_sha256}" "$(stat -c '%s' "${MODEL_PATH}")" > "${EVIDENCE_DIR}/model-verification.txt"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
render() {
  local source="$1" target="$2"
  sed \
    -e "s|__LLM_NAMESPACE__|${LLM_NAMESPACE}|g" \
    -e "s|__LLM_SERVICE__|${LLM_SERVICE}|g" \
    -e "s|__LLM_PORT__|${LLM_PORT}|g" \
    -e "s|__LLM_IMAGE__|${LLM_IMAGE}|g" \
    -e "s|__MODEL_FILE__|${MODEL_FILE}|g" \
    -e "s|__MODEL_DIR__|${MODEL_DIR}|g" \
    -e "s|__LLM_CONTEXT__|${LLM_CONTEXT}|g" \
    -e "s|__LLM_THREADS__|${LLM_THREADS}|g" \
    -e "s|__LLM_PARALLEL__|${LLM_PARALLEL}|g" \
    "${source}" > "${target}"
}
render "${REPO_ROOT}/kubernetes/llm/namespace.yaml" "${work}/namespace.yaml"
render "${REPO_ROOT}/kubernetes/llm/service.yaml.tpl" "${work}/service.yaml"
render "${REPO_ROOT}/kubernetes/llm/deployment.yaml.tpl" "${work}/deployment.yaml"

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f "${work}/namespace.yaml"
kubectl apply -f "${work}/service.yaml"
kubectl apply -f "${work}/deployment.yaml"
kubectl -n "${LLM_NAMESPACE}" rollout status deployment/"${LLM_SERVICE}" --timeout=20m
kubectl -n "${LLM_NAMESPACE}" wait --for=condition=Available deployment/"${LLM_SERVICE}" --timeout=60s

cp "${work}/namespace.yaml" "${EVIDENCE_DIR}/namespace.yaml"
cp "${work}/service.yaml" "${EVIDENCE_DIR}/service.yaml"
cp "${work}/deployment.yaml" "${EVIDENCE_DIR}/deployment.yaml"
capture deployment kubectl -n "${LLM_NAMESPACE}" get deployment "${LLM_SERVICE}" -o wide
capture pods kubectl -n "${LLM_NAMESPACE}" get pods -o wide
capture service kubectl -n "${LLM_NAMESPACE}" get service "${LLM_SERVICE}" -o wide
capture image kubectl -n "${LLM_NAMESPACE}" get deployment "${LLM_SERVICE}" -o jsonpath='{.spec.template.spec.containers[0].image}'
write_result PASS 'llama.cpp server is Ready with the verified Gemma 4 E2B GGUF model on CPU.'
mark_state 05_llm_server.pass
finish_script PASS '06_monitoring.sh'
