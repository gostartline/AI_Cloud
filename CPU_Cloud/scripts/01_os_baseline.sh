#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "01_os_baseline.sh" "01_os_baseline"
require_root
has_state 00_precheck.pass || fail 'Run 00_precheck.sh first.'
new_evidence_dir os-baseline

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gpg jq iproute2 iputils-ping chrony \
  pciutils procps socat conntrack ebtables ethtool python3 tar xz-utils

timedatectl set-timezone UTC
systemctl enable --now chrony
swapoff -a
if grep -Eq '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab; then
  cp -a /etc/fstab "/etc/fstab.startline.$(date -u +%Y%m%dT%H%M%SZ).bak"
  sed -ri '/^[^#].*[[:space:]]swap[[:space:]]/s/^/# STARTLINE_DISABLED_SWAP /' /etc/fstab
fi

cat > /etc/modules-load.d/startline-kubernetes.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/99-startline-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

capture time timedatectl
capture swap sh -c 'swapon --show; free -h'
capture modules sh -c 'lsmod | grep -E "^(overlay|br_netfilter)"'
capture sysctl sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
capture packages dpkg-query -W ca-certificates curl jq chrony socat conntrack ebtables ethtool
write_result PASS 'Ubuntu baseline, time sync, no swap, and Kubernetes kernel prerequisites are configured.'
mark_state 01_os_baseline.pass
finish_script PASS '02_containerd.sh'
