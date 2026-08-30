#!/usr/bin/env bash
set -Eeuo pipefail

ufw_is_active() {
  command -v ufw >/dev/null 2>&1 || return 1
  ufw status 2>/dev/null |
    awk '$1 == "Status:" { active=($2 == "active") } END { exit(active ? 0 : 1) }'
}

ufw_pod_cidr_rule_present() {
  local pod_cidr="$1"
  command -v ufw >/dev/null 2>&1 || return 1
  ufw status numbered 2>/dev/null |
    awk -v pod_cidr="${pod_cidr}" '
      index($0, pod_cidr) && index($0, "cni0") && index($0, "ALLOW IN") { found=1 }
      END { exit(found ? 0 : 1) }
    '
}

ensure_ufw_pod_cidr_rule() {
  local pod_cidr="$1"
  command -v ufw >/dev/null 2>&1 || return 0
  ufw_is_active || return 0
  ufw_pod_cidr_rule_present "${pod_cidr}" || ufw allow in on cni0 from "${pod_cidr}"
}
