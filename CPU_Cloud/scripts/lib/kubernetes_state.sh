#!/usr/bin/env bash
set -Eeuo pipefail

kubeadm_existing_cluster_healthy() {
  local kube_root="${1:-/etc/kubernetes}"
  [[ -f "${kube_root}/admin.conf" ]] || return 1
  KUBECONFIG="${kube_root}/admin.conf" kubectl get --raw=/readyz >/dev/null 2>&1
}

kubeadm_state_present() {
  local kube_root="${1:-/etc/kubernetes}" manifest
  [[ -f "${kube_root}/admin.conf" ]] && return 0

  for manifest in \
    kube-apiserver.yaml \
    kube-controller-manager.yaml \
    kube-scheduler.yaml \
    etcd.yaml
  do
    [[ -f "${kube_root}/manifests/${manifest}" ]] && return 0
  done

  return 1
}
