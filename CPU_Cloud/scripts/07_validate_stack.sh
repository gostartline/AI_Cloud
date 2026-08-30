#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
source "${SCRIPT_DIR}/lib/llm_validation.sh"
start_script "07_validate_stack.sh" "07_stack_validation"
require_root
has_state 06_monitoring.pass || fail 'Run 06_monitoring.sh first.'
require_cmd curl
require_cmd jq
new_evidence_dir stack-validation
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl wait --for=condition=Ready node --all --timeout=60s
kubectl -n "${LLM_NAMESPACE}" wait --for=condition=Available deployment/"${LLM_SERVICE}" --timeout=60s
kubectl -n "${PROMETHEUS_NAMESPACE}" wait --for=condition=Available deployment/prometheus deployment/grafana --timeout=60s

llm_pf_log="${EVIDENCE_DIR}/llm-port-forward.log"
prom_pf_log="${EVIDENCE_DIR}/prometheus-port-forward.log"
grafana_pf_log="${EVIDENCE_DIR}/grafana-port-forward.log"
kubectl -n "${LLM_NAMESPACE}" port-forward --address 127.0.0.1 service/"${LLM_SERVICE}" 18080:"${LLM_PORT}" >"${llm_pf_log}" 2>&1 &
llm_pid=$!
kubectl -n "${PROMETHEUS_NAMESPACE}" port-forward --address 127.0.0.1 service/prometheus 19090:9090 >"${prom_pf_log}" 2>&1 &
prom_pid=$!
kubectl -n "${PROMETHEUS_NAMESPACE}" port-forward --address 127.0.0.1 service/grafana 13000:3000 >"${grafana_pf_log}" 2>&1 &
grafana_pid=$!
cleanup() {
  kill "${llm_pid}" "${prom_pid}" "${grafana_pid}" 2>/dev/null || true
  wait "${llm_pid}" "${prom_pid}" "${grafana_pid}" 2>/dev/null || true
}
trap cleanup EXIT

wait_http() {
  local url="$1" label="$2" attempt
  for attempt in $(seq 1 60); do
    if curl --silent --show-error --fail --connect-timeout 2 --max-time 5 "${url}" >"${EVIDENCE_DIR}/${label}.http" 2>"${EVIDENCE_DIR}/${label}.stderr"; then
      return 0
    fi
    sleep 2
  done
  fail "HTTP endpoint did not become ready: ${label} (${url})"
}
wait_http "http://127.0.0.1:18080/health" llm-health
wait_http "http://127.0.0.1:19090/-/ready" prometheus-ready
wait_http "http://127.0.0.1:13000/api/health" grafana-health

jq -n \
  --arg prompt 'Reply with exactly: CPU prevalidation PASS.' \
  '{model:"gemma-4-E2B",messages:[{role:"user",content:$prompt}],temperature:0,max_tokens:128,stream:false}' \
  > "${EVIDENCE_DIR}/inference-request.json"
curl --silent --show-error --fail --connect-timeout 5 --max-time 180 \
  -H 'Content-Type: application/json' \
  --data @"${EVIDENCE_DIR}/inference-request.json" \
  'http://127.0.0.1:18080/v1/chat/completions' \
  > "${EVIDENCE_DIR}/inference-response.json"
validate_llm_response \
  "${EVIDENCE_DIR}/inference-response.json" \
  'CPU prevalidation PASS.' \
  "${EVIDENCE_DIR}/inference-response-summary.json" ||
  fail 'LLM inference response did not match the expected assistant content and metadata.'

curl --silent --show-error --fail --connect-timeout 5 --max-time 10 \
  --get --data-urlencode 'query=up{job="llm"}' \
  'http://127.0.0.1:19090/api/v1/query' \
  > "${EVIDENCE_DIR}/prometheus-llm-query.json"
jq -e '.data.result | length > 0 and any(.[]; .value[1] == "1")' \
  "${EVIDENCE_DIR}/prometheus-llm-query.json" >/dev/null ||
  fail 'Prometheus did not report the LLM target as up.'

cat > "${EVIDENCE_DIR}/llm-validation-public.md" <<EOF
# CPU LLM Validation

- Model family: Gemma 4 E2B
- Runtime: llama.cpp server
- CPU inference health: PASS
- Chat completion: PASS
EOF
cat > "${EVIDENCE_DIR}/monitoring-validation-public.md" <<EOF
# CPU Monitoring Validation

- Prometheus readiness: PASS
- Grafana health: PASS
- LLM metrics scrape: PASS
EOF
capture nodes kubectl get nodes -o wide
capture pods kubectl get pods --all-namespaces -o wide
capture llm_metrics curl --silent --show-error --fail 'http://127.0.0.1:18080/metrics'
write_result PASS 'CPU LLM health, chat completion, Prometheus scrape, and Grafana health checks passed.'
mark_state 07_stack_validation.pass
finish_script PASS '99_collect_evidence.sh'
