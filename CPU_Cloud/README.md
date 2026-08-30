# CPU Cloud — Implementation Showcase

This directory is a public, reviewable source-code showcase for the CPU Cloud deployment path. It is not a copy of the complete private operating environment.

## Status boundary

- **CPU Cloud:** Built / E2E Validated on a single CPU VM.
- **GPU Cloud:** Designed / Hardware Validation Pending.

The implementation source shows the deployment decisions. The corresponding runtime results are in [`../STARTLINE_Evidence/README.md`](../STARTLINE_Evidence/README.md).

## Read the implementation in order

```text
Ubuntu 24.04
  → OS baseline
  → containerd / runc / CNI
  → kubeadm Kubernetes
  → Flannel / CoreDNS / UFW-aware networking
  → llama.cpp + Gemma 4 E2B
  → Prometheus / Grafana
  → OpenAI-compatible API and E2E validation
  → sanitized evidence collection
```

| Layer | Implementation | What to inspect |
|---|---|---|
| Host bootstrap | [`scripts/00_bootstrap.sh`](./scripts/00_bootstrap.sh) | Minimal Ubuntu prerequisites and required command checks |
| Host baseline | [`scripts/00_precheck.sh`](./scripts/00_precheck.sh) | CPU, memory, storage, OS, and pinned configuration checks |
| OS baseline | [`scripts/01_os_baseline.sh`](./scripts/01_os_baseline.sh) | Kernel prerequisites, time sync, and swap posture |
| Container runtime | [`scripts/02_containerd.sh`](./scripts/02_containerd.sh) | Version-pinned containerd, runc, CNI downloads, and SHA-256 verification |
| Kubernetes packages | [`scripts/03_kubernetes_packages.sh`](./scripts/03_kubernetes_packages.sh) | Repository key handling and pinned kubeadm/kubelet/kubectl packages |
| Cluster networking | [`scripts/04_single_node_cluster.sh`](./scripts/04_single_node_cluster.sh) | kubeadm, Flannel, UFW Pod-CIDR rule, CoreDNS, EndpointSlice, and disposable DNS validation |
| Model serving | [`scripts/download_model.sh`](./scripts/download_model.sh) and [`scripts/05_llm_server.sh`](./scripts/05_llm_server.sh) | GGUF checksum verification and llama.cpp / Gemma Deployment rendering |
| Monitoring | [`scripts/06_monitoring.sh`](./scripts/06_monitoring.sh) | Prometheus scrape configuration and Grafana deployment |
| E2E validation | [`scripts/07_validate_stack.sh`](./scripts/07_validate_stack.sh) | Health checks, OpenAI-compatible chat completion, metrics query, and result validation |

## Supporting code

- [`scripts/lib/common.sh`](./scripts/lib/common.sh): configuration loading, logging, state markers, and fail-fast behavior.
- [`scripts/lib/evidence.sh`](./scripts/lib/evidence.sh): phase evidence boundaries, result records, sanitization helpers, and manifest functions.
- [`scripts/lib/kubernetes_state.sh`](./scripts/lib/kubernetes_state.sh): detection of healthy and partial kubeadm state.
- [`scripts/lib/ufw.sh`](./scripts/lib/ufw.sh): idempotent Pod-CIDR allowance for active UFW without disabling the firewall.
- [`scripts/lib/llm_validation.sh`](./scripts/lib/llm_validation.sh): rejects reasoning-only or malformed responses and requires the expected assistant content.
- [`config.env.example`](./config.env.example): public configuration shape and pinned non-secret defaults. Copy it locally to `config.env`; never commit the resulting runtime file.

## Kubernetes manifests and templates

The public templates intentionally use placeholders instead of rendered environment-specific manifests:

- [LLM namespace](./kubernetes/llm/namespace.yaml)
- [LLM Service](./kubernetes/llm/service.yaml.tpl)
- [llama.cpp / Gemma Deployment](./kubernetes/llm/deployment.yaml.tpl)
- [Monitoring namespace](./kubernetes/monitoring/namespace.yaml)
- [Prometheus configuration](./kubernetes/monitoring/prometheus-config.yaml.tpl)
- [Prometheus Deployment and Service](./kubernetes/monitoring/prometheus.yaml.tpl)
- [Grafana provisioning](./kubernetes/monitoring/grafana-provisioning.yaml)
- [Grafana Deployment and Service](./kubernetes/monitoring/grafana.yaml.tpl)

These templates demonstrate architecture and configuration choices. They are not a production security baseline; review images, storage, access control, and secrets management before reuse.

## Validation caveat

The complete source repository contains static/fixture tests, but this showcase omits the test harness because it depends on the private setup hub and collector. The **Built / E2E Validated** status comes from the separate sanitized runtime Evidence package, and the original evidence collector's packaging failure remains documented there.

The showcase intentionally omits the runtime `config.env`, raw logs, internal Evidence, host-specific rendered manifests, the full setup hub, and the raw evidence collector package.
