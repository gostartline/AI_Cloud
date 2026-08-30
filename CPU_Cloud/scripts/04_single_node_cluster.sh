#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
source "${SCRIPT_DIR}/lib/kubernetes_state.sh"
source "${SCRIPT_DIR}/lib/ufw.sh"
start_script "04_single_node_cluster.sh" "04_single_node_cluster"
require_root
require_cmd jq
has_state 03_kubernetes_packages.pass || fail 'Run 03_kubernetes_packages.sh first.'
new_evidence_dir single-node-cluster

export KUBECONFIG=/etc/kubernetes/admin.conf
if kubeadm_existing_cluster_healthy /etc/kubernetes; then
  info 'Healthy existing single-node control plane detected; kubeadm init is not rerun.'
elif kubeadm_state_present /etc/kubernetes; then
  fail 'Existing Kubernetes state is unhealthy; automatic reset is disabled.'
else
  api_address="${KUBE_API_ADDRESS:-$(hostname -I | awk '
    {
      for (i=1; i<=NF; i++) {
        if ($i !~ /^127\./ && $i !~ /:/ && address == "") address=$i
      }
    }
    END { print address }
  ')}"
  [[ "${api_address}" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || fail 'KUBE_API_ADDRESS must resolve to a host IPv4 address'
  node_name="${CPU_NODE_NAME:-$(hostname -s)}"
  mkdir -p /etc/kubernetes/startline
  cat > /etc/kubernetes/startline/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${api_address}
  bindPort: 6443
nodeRegistration:
  name: ${node_name}
  criSocket: unix:///run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v${KUBERNETES_VERSION}
networking:
  podSubnet: ${POD_CIDR}
  serviceSubnet: ${SERVICE_CIDR}
EOF
  kubeadm config validate --config /etc/kubernetes/startline/kubeadm-config.yaml
  kubeadm init --config /etc/kubernetes/startline/kubeadm-config.yaml
  install -d -m 0700 /root/.kube
  install -m 0600 /etc/kubernetes/admin.conf /root/.kube/config
fi

export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get --raw=/readyz >/dev/null || fail 'Kubernetes API readyz failed'
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

work="$(mktemp -d)"
dns_validation_pod="startline-dns-validation"
cleanup() {
  kubectl -n default delete pod "${dns_validation_pod}" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
  rm -rf "${work}"
}
trap cleanup EXIT
flannel_url="https://raw.githubusercontent.com/flannel-io/flannel/v${FLANNEL_VERSION}/Documentation/kube-flannel.yml"
curl --fail --location --output "${work}/kube-flannel.yml" "${flannel_url}"
sed -E -i "s#\"Network\"[[:space:]]*:[[:space:]]*\"[^\"]+\"#\"Network\": \"${POD_CIDR}\"#" "${work}/kube-flannel.yml"
kubectl apply -f "${work}/kube-flannel.yml"
kubectl -n kube-flannel rollout status daemonset/kube-flannel-ds --timeout=10m
kubectl wait --for=condition=Ready node --all --timeout=10m

ufw_rule_action="not-applicable"
if ! command -v ufw >/dev/null 2>&1; then
  ufw_rule_action="ufw-not-installed"
elif ! ufw_is_active; then
  ufw_rule_action="ufw-inactive"
elif ufw_pod_cidr_rule_present "${POD_CIDR}"; then
  ufw_rule_action="already-present"
else
  ensure_ufw_pod_cidr_rule "${POD_CIDR}"
  ufw_rule_action="added"
fi
if command -v ufw >/dev/null 2>&1; then
  capture ufw_status_verbose ufw status verbose
  capture ufw_rules ufw status numbered
else
  printf 'ufw status verbose unavailable: ufw is not installed.\n' > "${EVIDENCE_DIR}/ufw_status_verbose.stdout.txt"
  printf 'ufw status numbered unavailable: ufw is not installed.\n' > "${EVIDENCE_DIR}/ufw_rules.stdout.txt"
fi
printf 'action=%s\npod_cidr=%s\nrule=allow in on cni0 from %s\n' \
  "${ufw_rule_action}" "${POD_CIDR}" "${POD_CIDR}" > "${EVIDENCE_DIR}/ufw-rule-action.txt"

kubectl -n kube-system rollout status deployment/coredns --timeout=10m
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=kube-dns --timeout=5m
capture coredns_pods kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
capture kube_dns_service kubectl -n kube-system get service kube-dns -o yaml
capture kube_dns_endpointslices kubectl -n kube-system get endpointslice -l kubernetes.io/service-name=kube-dns -o yaml
capture coredns_logs kubectl -n kube-system logs -l k8s-app=kube-dns --tail=200 --prefix
coredns_ready_count="$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o json | jq -r '[.items[]? | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))] | length')"
(( coredns_ready_count >= 1 )) || fail 'CoreDNS has no Ready Pod.'
kubectl -n kube-system get service kube-dns >/dev/null || fail 'kube-dns Service is missing.'
endpoint_slice_ready_count="$(kubectl -n kube-system get endpointslice -l kubernetes.io/service-name=kube-dns -o json | jq -r '[.items[]?.endpoints[]? | select(.conditions.ready == true) | .addresses[]?] | length')"
(( endpoint_slice_ready_count >= 1 )) || fail 'kube-dns EndpointSlice has no Ready endpoint.'

kubectl -n default delete pod "${dns_validation_pod}" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
dns_run_rc=0
kubectl -n default run "${dns_validation_pod}" \
  --image=busybox:1.36.1 \
  --restart=Never \
  --command -- nslookup kubernetes.default.svc.cluster.local \
  > "${EVIDENCE_DIR}/dns-validation-create.stdout.txt" \
  2> "${EVIDENCE_DIR}/dns-validation-create.stderr.txt" || dns_run_rc=$?
if (( dns_run_rc != 0 )); then
  printf 'result=FAIL\nphase=pod-create\nexit_code=%s\n' "${dns_run_rc}" > "${EVIDENCE_DIR}/dns-validation-result.txt"
  fail 'DNS validation Pod could not be created.'
fi
dns_phase=""
for _ in $(seq 1 60); do
  dns_phase="$(kubectl -n default get pod "${dns_validation_pod}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  case "${dns_phase}" in
    Succeeded|Failed) break ;;
  esac
  sleep 1
done
capture dns_validation_pod kubectl -n default get pod "${dns_validation_pod}" -o yaml || true
capture dns_validation_logs kubectl -n default logs "${dns_validation_pod}" || true
if [[ "${dns_phase}" == Succeeded ]]; then
  printf 'result=PASS\nphase=%s\nhostname=kubernetes.default.svc.cluster.local\n' "${dns_phase}" > "${EVIDENCE_DIR}/dns-validation-result.txt"
else
  printf 'result=FAIL\nphase=%s\nhostname=kubernetes.default.svc.cluster.local\n' "${dns_phase:-unknown}" > "${EVIDENCE_DIR}/dns-validation-result.txt"
  fail "Cluster DNS validation failed (phase=${dns_phase:-unknown})."
fi

cp "${work}/kube-flannel.yml" "${EVIDENCE_DIR}/kube-flannel.yml"
capture cluster_info kubectl cluster-info
capture nodes kubectl get nodes -o wide
capture pods kubectl get pods --all-namespaces -o wide
capture cni kubectl -n kube-flannel get pods -o wide
write_result PASS 'Single-node kubeadm cluster is Ready with Flannel networking, UFW-aware Pod access, CoreDNS readiness, kube-dns endpoints, and in-cluster DNS validation.'
mark_state 04_single_node_cluster.pass
finish_script PASS '05_llm_server.sh'
