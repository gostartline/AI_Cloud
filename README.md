# AIF — AI Infrastructure Build & Validation

Japanese version: [README_JA.md](./README_JA.md)

AIF is a hands-on AI infrastructure portfolio. It shows how I designed, built, validated, and troubleshot a CPU-based Kubernetes and LLM serving stack, then separated the implementation from sanitized public evidence.

The implementation showcase is based on `53f0cf71c728fb52207d83c38007f9012ee23d77`. The evidence package keeps captured runtime provenance separate where the capture revision differs.

## At a glance

- A single-node Kubernetes platform on Ubuntu 24.04, using containerd/runc, Flannel, and CoreDNS.
- llama.cpp serving Gemma 4 E2B Q4_0 GGUF through an OpenAI-compatible API.
- Prometheus and Grafana monitoring, followed by LLM, monitoring, and end-to-end validation.
- Public evidence is sanitized and excludes credentials, raw logs, host-specific data, and unredacted client captures.

## Current Status

| Environment | Status | Scope |
|---|---|---|
| CPU Cloud | ✅ Built / E2E Validated | Kubernetes, networking, LLM serving, monitoring, API validation, evidence collection |
| GPU Cloud | 🟡 Designed / Hardware Validation Pending | CUDA, GPU Operator, multi-GPU, GPU monitoring, Slurm |

## Architecture

```text
Windows Client
      |
      | SSH Tunnel / OpenAI-compatible API
      v
Vultr Ubuntu 24.04
      |
      v
containerd / runc
      |
      v
Kubernetes
      |
      +-- Flannel
      +-- CoreDNS
      |
      +-- llama.cpp
      |      |
      |      +-- Gemma 4 E2B Q4_0
      |
      +-- Monitoring
             |
             +-- Prometheus
             +-- Grafana
```

The Windows client path was validated as a client-access path. The following supplementary captures show the client UI, the local API access path, and the returned OpenAI-compatible response:

![Windows client UI validation](./images/scr004.png)

![Local API and port-forward validation](./images/scr001.jpg)

![OpenAI-compatible inference response](./images/scr006.png)

These images are supplementary evidence; the sanitized validation summaries remain the primary evidence. Review the captures before redistribution if the target publication policy prohibits local URLs, terminal context, or host-specific UI details.

## CPU Cloud environment

| Item | Value |
|---|---|
| Provider | Vultr Dedicated CPU |
| Region | Tokyo |
| OS | Ubuntu 24.04 |
| Compute | 4 vCPU, 16 GB class |
| Runtime | containerd / runc |
| Orchestration | Kubernetes with kubeadm |
| Networking | Flannel, CoreDNS, UFW-aware validation |
| LLM runtime | llama.cpp |
| Model | Gemma 4 E2B Q4_0 GGUF |
| Monitoring | Prometheus, Grafana |
| Client validation | Windows 11 |

## Build flow and implementation links

```text
Ubuntu 24.04
    → OS Baseline
    → containerd / runc / CNI
    → kubeadm Kubernetes
    → Flannel / CoreDNS
    → llama.cpp
    → Gemma 4 E2B
    → Prometheus / Grafana
    → OpenAI-compatible API
    → E2E Validation
    → Evidence Collection
```

| Stage | Public implementation |
|---|---|
| Precheck | [`00_precheck.sh`](./CPU_Cloud/scripts/00_precheck.sh) |
| OS baseline | [`01_os_baseline.sh`](./CPU_Cloud/scripts/01_os_baseline.sh) |
| containerd / runc / CNI | [`02_containerd.sh`](./CPU_Cloud/scripts/02_containerd.sh) |
| Kubernetes packages | [`03_kubernetes_packages.sh`](./CPU_Cloud/scripts/03_kubernetes_packages.sh) |
| kubeadm, Flannel, CoreDNS, UFW, DNS validation | [`04_single_node_cluster.sh`](./CPU_Cloud/scripts/04_single_node_cluster.sh) |
| Model preparation | [`download_model.sh`](./CPU_Cloud/scripts/download_model.sh) |
| llama.cpp / Gemma serving | [`05_llm_server.sh`](./CPU_Cloud/scripts/05_llm_server.sh) |
| Prometheus / Grafana | [`06_monitoring.sh`](./CPU_Cloud/scripts/06_monitoring.sh) |
| LLM, monitoring, and E2E validation | [`07_validate_stack.sh`](./CPU_Cloud/scripts/07_validate_stack.sh) |
| Sanitized evidence summary | [`STARTLINE_Evidence`](./STARTLINE_Evidence/README.md) |

The original evidence collector and its private packaging context are intentionally outside this showcase. The public evidence summary is manually curated and documents that packaging caveat.

## Implementation Showcase

The selected source is readable enough to inspect the engineering decisions without publishing the entire operational environment:

- [`CPU_Cloud/README.md`](./CPU_Cloud/README.md) — implementation map and public boundary.
- [`04_single_node_cluster.sh`](./CPU_Cloud/scripts/04_single_node_cluster.sh) — kubeadm bootstrap, Flannel, CoreDNS readiness, UFW rules, and DNS validation.
- [`05_llm_server.sh`](./CPU_Cloud/scripts/05_llm_server.sh) — llama.cpp deployment and Gemma configuration.
- [`06_monitoring.sh`](./CPU_Cloud/scripts/06_monitoring.sh) — Prometheus and Grafana deployment.
- [`07_validate_stack.sh`](./CPU_Cloud/scripts/07_validate_stack.sh) — inference, monitoring, and E2E checks.
- [`CPU_Cloud/kubernetes/llm`](./CPU_Cloud/kubernetes/llm) and [`CPU_Cloud/kubernetes/monitoring`](./CPU_Cloud/kubernetes/monitoring) — reviewed templates/manifests.
- [`CPU_Cloud/scripts/lib`](./CPU_Cloud/scripts/lib) — focused helpers for validation, state handling, UFW, and safe evidence boundaries.

Runtime `config.env`, credentials, tokens/PATs, SSH keys, private evidence, raw logs, host-specific data, and environment-specific secrets are not part of the public implementation tree.

## Representative CPU performance

| Measurement | Result |
|---|---:|
| CPU | 4 vCPU |
| Memory | 16 GB class |
| Model | Gemma 4 E2B Q4_0 |
| Runtime | llama.cpp |
| Prompt tokens | 35 |
| Completion tokens | 269 |
| Generation time | ~31.5 sec |
| Generation throughput | ~8.5 tokens/sec |
| Japanese response | PASS |

This is a representative CPU-only client/API measurement for portfolio communication, not a GPU benchmark. A separate machine-readable validation summary records another fixed prompt at approximately 8.8 tokens/sec; both are preproduction measurements on the validated CPU stack.

## Inference behavior analysis

The validation request uses `chat_template_kwargs.enable_thinking=false`. Reasoning-enabled generation adds latency and can consume output tokens; disabling it retained the final Japanese response while avoiding unnecessary reasoning output for this validation path. This is an inference-behavior observation, not a claim of general model performance tuning.

## Validation results

- Ubuntu 24.04 baseline: PASS
- containerd / runc / CNI: PASS
- Kubernetes packages and single-node kubeadm cluster: PASS
- Flannel networking and CoreDNS readiness: PASS
- DNS validation: PASS
- llama.cpp and Gemma serving: PASS
- OpenAI-compatible API inference: PASS
- Japanese inference response: PASS
- Prometheus and Grafana: PASS
- Windows client access path: PASS
- LLM, monitoring, and E2E validation: PASS
- Sanitized evidence summary: available

The original collector run contains a packaging failure marker. Therefore “Evidence Collection” means the sanitized, manually rebuilt public evidence derivative is available; it does not claim that the original collector completed cleanly.

## Troubleshooting and engineering lessons

### Script directory collision

- Symptom: a shared shell helper resolved paths against an unexpected script directory.
- Root cause: a generic `SCRIPT_DIR` variable collided with a caller's path context.
- Resolution: isolate helper path variables and make path resolution explicit.
- Engineering lesson: shell libraries need namespaced state and deterministic path ownership.

### `pipefail` / SIGPIPE exit code 141

- Symptom: an early package-install attempt stopped with exit code 141 while consuming piped output.
- Root cause: a downstream command closed the pipe before the producer finished under `pipefail`.
- Resolution: replace fragile pipelines with bounded, explicit command steps and rerun the gate.
- Engineering lesson: shell success criteria must distinguish pipeline behavior from package-manager failure.

### Kubernetes partial state

- Symptom: an early cluster check found an unhealthy existing state.
- Root cause: the host was not in a clean first-boot state.
- Resolution: stop on partial state, inspect it, and validate the later clean single-node path instead of silently resetting it.
- Engineering lesson: infrastructure scripts should be restart-aware and should not destroy unknown state by default.

### UFW and the CoreDNS dependency chain

- Symptom: Pod/API traffic timed out, CoreDNS watch operations failed, Service DNS failed, and a Prometheus target was initially down.
- Root cause: a routed UFW deny blocked the cluster traffic path.
- Resolution: add the required CNI/pod-network allowance, then recheck CoreDNS, DNS resolution, monitoring, and the API path.
- Engineering lesson: Kubernetes networking failures must be traced across firewall, overlay, DNS, service discovery, and observability—not treated as isolated pod failures.

### LLM response-content validation

- Symptom: an early LLM validation saw a response envelope but no usable assistant content.
- Root cause: checking transport success alone did not prove an inference result.
- Resolution: validate actual assistant content and the expected Japanese response path.
- Engineering lesson: API health checks must assert semantic output, not only HTTP status or JSON shape.

### Evidence packaging failure

- Symptom: the original collector failed while writing its public/internal output and manifest.
- Root cause: packaging path/state handling was not cleanly separated from runtime collection.
- Resolution: manually rebuild a sanitized derivative and record the limitation in the audit.
- Engineering lesson: evidence generation is a separate release stage with its own failure modes and review gate.

## Public Evidence

Evidence is deliberately separated from implementation:

**Implementation** → [`CPU_Cloud`](./CPU_Cloud/README.md)<br>
**Evidence** → [`STARTLINE_Evidence`](./STARTLINE_Evidence/README.md)

The evidence package contains sanitized architecture, deployment, validation, inference, monitoring, and Windows-client summaries. Start with [`STARTLINE_Evidence/README.md`](./STARTLINE_Evidence/README.md).

## GPU Cloud boundary

GPU Cloud remains **Designed / Hardware Validation Pending**. The design scope covers CUDA, GPU Operator, multi-GPU scheduling, GPU monitoring, and Slurm. This repository contains no GPU throughput, stability, or hardware-validation claim.

## Published repository layout

```text
AIF/
├─ README.md
├─ README_JA.md
├─ CPU_Cloud/
│  ├─ scripts/
│  ├─ kubernetes/
│  └─ README.md
├─ GPU_Cloud/
│  └─ design/
└─ STARTLINE_Evidence/
   └─ sanitized validation summaries
```

The implementation and evidence layers are separated so that both construction decisions and validated results can be reviewed directly.
