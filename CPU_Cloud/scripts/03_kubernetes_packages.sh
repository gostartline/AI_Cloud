#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "03_kubernetes_packages.sh" "03_kubernetes_packages"
require_root
has_state 02_containerd.pass || fail 'Run 02_containerd.sh first.'
new_evidence_dir kubernetes-packages

require_cmd apt-get
require_cmd apt-cache
require_cmd gpg
install -d -m 0755 /etc/apt/keyrings
tmp_key="/etc/apt/keyrings/kubernetes-apt-keyring.gpg.tmp"
curl --fail --location "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/deb/Release.key" | gpg --dearmor > "${tmp_key}"
install -m 0644 "${tmp_key}" /etc/apt/keyrings/kubernetes-apt-keyring.gpg
rm -f "${tmp_key}"
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}/deb/ /
EOF
apt-get update
apt_ver="$(resolve_apt_package_version kubeadm "${KUBERNETES_VERSION}")"
[[ -n "${apt_ver}" ]] || fail "Kubernetes package ${KUBERNETES_VERSION} is not available in the v${KUBERNETES_MINOR} repository"
apt-get install -y "kubelet=${apt_ver}" "kubeadm=${apt_ver}" "kubectl=${apt_ver}"
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

actual_kubeadm_version="$(kubeadm version -o short)"
[[ "${actual_kubeadm_version}" == "v${KUBERNETES_VERSION}" ]] || fail "kubeadm version mismatch: ${actual_kubeadm_version}"
actual_kubelet_version="$(kubelet --version)"
[[ "${actual_kubelet_version}" == "Kubernetes v${KUBERNETES_VERSION}" ]] || fail "kubelet version mismatch: ${actual_kubelet_version}"
capture kubeadm_version kubeadm version -o short
capture kubelet_version kubelet --version
capture kubectl_version kubectl version --client=true
write_result PASS "Kubernetes components pinned to ${KUBERNETES_VERSION} and configured for containerd CRI."
mark_state 03_kubernetes_packages.pass
finish_script PASS '04_single_node_cluster.sh'
