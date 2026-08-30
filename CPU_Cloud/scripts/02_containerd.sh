#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "02_containerd.sh" "02_containerd"
require_root
has_state 01_os_baseline.pass || fail 'Run 01_os_baseline.sh first.'
new_evidence_dir containerd

require_cmd curl
require_cmd sha256sum
require_cmd tar
arch=amd64
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

containerd_archive="containerd-${CONTAINERD_VERSION}-linux-${arch}.tar.gz"
containerd_url="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${containerd_archive}"
curl --fail --location --retry 3 --output "${work}/${containerd_archive}" "${containerd_url}"
curl --fail --location --retry 3 --output "${work}/containerd.sha256sum" "${containerd_url}.sha256sum"
expected_containerd="$(awk 'NR==1{print $1}' "${work}/containerd.sha256sum")"
[[ "${expected_containerd}" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'containerd checksum file did not contain a SHA256'
printf '%s  %s\n' "${expected_containerd}" "${work}/${containerd_archive}" | sha256sum -c -
tar -C /usr/local -xzf "${work}/${containerd_archive}"

runc_url="https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
runc_checksum_url="https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.sha256sum"
curl --fail --location --retry 3 --output "${work}/runc.amd64" "${runc_url}"
curl --fail --location --retry 3 --output "${work}/runc.sha256sum" "${runc_checksum_url}"
expected_runc="$(awk '$2=="runc.amd64" || $2=="*runc.amd64" {print $1; exit}' "${work}/runc.sha256sum")"
[[ "${expected_runc}" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'runc checksum file did not contain the runc.amd64 SHA256'
printf '%s  %s\n' "${expected_runc}" "${work}/runc.amd64" | sha256sum -c -
install -m 0755 "${work}/runc.amd64" /usr/local/sbin/runc

mkdir -p /opt/cni/bin
cni_archive="cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
cni_url="https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/${cni_archive}"
curl --fail --location --retry 3 --output "${work}/${cni_archive}" "${cni_url}"
curl --fail --location --retry 3 --output "${work}/cni.sha256" "${cni_url}.sha256"
expected_cni="$(awk 'NR==1{print $1}' "${work}/cni.sha256")"
[[ "${expected_cni}" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'CNI checksum file did not contain a SHA256'
printf '%s  %s\n' "${expected_cni}" "${work}/${cni_archive}" | sha256sum -c -
tar -C /opt/cni/bin -xzf "${work}/${cni_archive}"
(
  cd /opt/cni/bin
  find . -maxdepth 1 -type f -printf '%P\0' | sort -z | xargs -0 -r sha256sum
) > "${EVIDENCE_DIR}/cni-installed-files.sha256"

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -ri 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
cat > /etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now containerd
sleep 2
systemctl is-active --quiet containerd || fail 'containerd service is not active'

actual_containerd_version="$(containerd --version)"
[[ "${actual_containerd_version}" == *"v${CONTAINERD_VERSION}"* ]] || fail "containerd version mismatch: ${actual_containerd_version}"
actual_runc_version="$(runc --version)"
[[ "${actual_runc_version}" == *"${RUNC_VERSION}"* ]] || fail "runc version mismatch: ${actual_runc_version}"
ctr plugins ls | awk '$1=="io.containerd.grpc.v1" && $2=="cri" && $4=="ok" {found=1} END{exit(found?0:1)}' || fail 'containerd CRI plugin is not ready'

cp "${work}/containerd.sha256sum" "${EVIDENCE_DIR}/containerd-upstream.sha256sum"
cp "${work}/runc.sha256sum" "${EVIDENCE_DIR}/runc-upstream.sha256sum"
cp "${work}/cni.sha256" "${EVIDENCE_DIR}/cni-upstream.sha256"
capture containerd_version containerd --version
capture runc_version runc --version
capture containerd_plugins ctr plugins ls
capture service systemctl status containerd --no-pager
capture config grep -E 'SystemdCgroup|disabled_plugins' /etc/containerd/config.toml
write_result PASS 'containerd, runc, CNI plugins, and the CRI plugin are installed at configured versions.'
mark_state 02_containerd.pass
finish_script PASS '03_kubernetes_packages.sh'
