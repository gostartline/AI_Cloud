#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "06_monitoring.sh" "06_monitoring"
require_root
has_state 05_llm_server.pass || fail 'Run 05_llm_server.sh first.'
require_value PROMETHEUS_NAMESPACE
require_value PROMETHEUS_IMAGE
require_value GRAFANA_IMAGE
new_evidence_dir monitoring

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
render() {
  local source="$1" target="$2"
  sed \
    -e "s|__PROMETHEUS_NAMESPACE__|${PROMETHEUS_NAMESPACE}|g" \
    -e "s|__LLM_NAMESPACE__|${LLM_NAMESPACE}|g" \
    -e "s|__LLM_SERVICE__|${LLM_SERVICE}|g" \
    -e "s|__LLM_PORT__|${LLM_PORT}|g" \
    -e "s|__PROMETHEUS_IMAGE__|${PROMETHEUS_IMAGE}|g" \
    -e "s|__GRAFANA_IMAGE__|${GRAFANA_IMAGE}|g" \
    "${source}" > "${target}"
}
render "${REPO_ROOT}/kubernetes/monitoring/namespace.yaml" "${work}/namespace.yaml"
render "${REPO_ROOT}/kubernetes/monitoring/prometheus-config.yaml.tpl" "${work}/prometheus-config.yaml"
render "${REPO_ROOT}/kubernetes/monitoring/prometheus.yaml.tpl" "${work}/prometheus.yaml"
render "${REPO_ROOT}/kubernetes/monitoring/grafana-provisioning.yaml" "${work}/grafana-provisioning.yaml"
render "${REPO_ROOT}/kubernetes/monitoring/grafana.yaml.tpl" "${work}/grafana.yaml"

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f "${work}/namespace.yaml"
kubectl apply -f "${work}/prometheus-config.yaml"
kubectl apply -f "${work}/prometheus.yaml"
kubectl apply -f "${work}/grafana-provisioning.yaml"
kubectl apply -f "${work}/grafana.yaml"
kubectl -n "${PROMETHEUS_NAMESPACE}" rollout status deployment/prometheus --timeout=10m
kubectl -n "${PROMETHEUS_NAMESPACE}" rollout status deployment/grafana --timeout=10m
kubectl -n "${PROMETHEUS_NAMESPACE}" wait --for=condition=Available deployment/prometheus deployment/grafana --timeout=60s

cp "${work}/namespace.yaml" "${EVIDENCE_DIR}/namespace.yaml"
cp "${work}/prometheus-config.yaml" "${EVIDENCE_DIR}/prometheus-config.yaml"
cp "${work}/prometheus.yaml" "${EVIDENCE_DIR}/prometheus.yaml"
cp "${work}/grafana-provisioning.yaml" "${EVIDENCE_DIR}/grafana-provisioning.yaml"
cp "${work}/grafana.yaml" "${EVIDENCE_DIR}/grafana.yaml"
capture pods kubectl -n "${PROMETHEUS_NAMESPACE}" get pods -o wide
capture services kubectl -n "${PROMETHEUS_NAMESPACE}" get services -o wide
capture prometheus_deployment kubectl -n "${PROMETHEUS_NAMESPACE}" get deployment prometheus -o wide
capture grafana_deployment kubectl -n "${PROMETHEUS_NAMESPACE}" get deployment grafana -o wide
write_result PASS 'Prometheus and Grafana deployments are Ready; Prometheus is configured to scrape the LLM metrics endpoint.'
mark_state 06_monitoring.pass
finish_script PASS '07_validate_stack.sh'
