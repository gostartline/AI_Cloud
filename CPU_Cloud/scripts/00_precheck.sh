#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/evidence.sh"
start_script "00_precheck.sh" "00_precheck"
require_root
has_state 00_bootstrap.pass || fail 'Run 00_bootstrap.sh first.'
new_evidence_dir host-precheck

require_cmd awk
require_cmd df
require_cmd free
require_cmd lscpu
require_cmd curl
require_cmd ip
require_cmd ss

source /etc/os-release
if [[ " ${SUPPORTED_UBUNTU_VERSIONS} " != *" ${VERSION_ID} "* ]]; then
  fail "Unsupported Ubuntu version: ${VERSION_ID}; supported=${SUPPORTED_UBUNTU_VERSIONS}"
fi
[[ "${ID}" == ubuntu ]] || fail "OS must be Ubuntu: ${ID}"
[[ "$(uname -m)" == x86_64 ]] || fail "CPU architecture must be x86_64: $(uname -m)"

require_value TARGET_MEMORY_GIB
[[ "${TARGET_MEMORY_GIB}" =~ ^[0-9]+$ ]] || fail 'TARGET_MEMORY_GIB must be an integer.'
require_value TARGET_LOCAL_STORAGE_GIB
[[ "${TARGET_LOCAL_STORAGE_GIB}" =~ ^[0-9]+$ ]] || fail 'TARGET_LOCAL_STORAGE_GIB must be an integer.'

cpu_count="$(nproc)"
ram_mib="$(awk '/^MemTotal:/{printf "%d", $2 / 1024; exit}' /proc/meminfo)"
min_ram_mib="$(( TARGET_MEMORY_GIB * 1024 * 95 / 100 ))"
disk_gib="$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')"
assert_ge "${cpu_count}" "${TARGET_CPU_VCPU}" 'vCPU'
assert_ge "${ram_mib}" "${min_ram_mib}" 'RAM MiB (95% of target)'
assert_ge "${disk_gib}" "${MIN_ROOT_DISK_GIB}" 'free root disk GiB'

require_value KUBERNETES_VERSION
require_value CONTAINERD_VERSION
require_value LLM_IMAGE
require_value MODEL_FILE
require_value MODEL_PATH
require_value MODEL_DIR
require_value MODEL_SHA256
require_value PROMETHEUS_IMAGE
require_value GRAFANA_IMAGE
require_value TARGET_CPU_CLASS
require_value TARGET_REGION
[[ "${MODEL_SHA256}" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'MODEL_SHA256 must be a 64-character SHA256.'

capture os_release cat /etc/os-release
capture uname uname -a
capture cpu lscpu
capture memory free -h
capture disk df -h
capture ip ip -br addr
capture route ip route
capture listening ss -lntup
printf 'target_cpu_vcpu=%s\ntarget_memory_gib=%s\ntarget_local_storage_gib=%s\ntarget_cpu_class=%s\ntarget_region=%s\ntarget_hourly_usd=%s\nminimum_free_root_disk_gib=%s\n' \
  "${TARGET_CPU_VCPU}" "${TARGET_MEMORY_GIB}" "${TARGET_LOCAL_STORAGE_GIB}" \
  "${TARGET_CPU_CLASS}" "${TARGET_REGION}" "${TARGET_HOURLY_USD}" "${MIN_ROOT_DISK_GIB}" > "${EVIDENCE_DIR}/target-profile.txt"
printf 'measured_cpu_vcpu=%s\nmeasured_memory_mib=%s\nminimum_memory_mib=%s\nmeasured_free_root_disk_gib=%s\n' \
  "${cpu_count}" "${ram_mib}" "${min_ram_mib}" "${disk_gib}" > "${EVIDENCE_DIR}/host-measured.txt"

write_result PASS 'Host runtime requirements satisfy the CPU prevalidation baseline.'
mark_state 00_precheck.pass
finish_script PASS '01_os_baseline.sh'
