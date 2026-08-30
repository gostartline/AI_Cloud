# AIF Public Evidence

This package presents the public evidence for the AIF AI infrastructure project.

## Implementation and Evidence are separate

- [Implementation → CPU_Cloud](../CPU_Cloud/README.md): selected deployment, serving, monitoring, and validation source code.
- **Evidence → STARTLINE_Evidence:** sanitized results from the recorded CPU Cloud run.

The implementation showcase explains how the system was built; this directory explains what the recorded environment actually demonstrated. Neither layer includes runtime credentials or raw internal evidence.

## Executive summary

The validated scope is a CPU-only prevalidation path on one Ubuntu node:

```text
Deployment scripts
    -> containerd / runc / CNI
    -> single-node Kubernetes
    -> llama.cpp server
    -> Gemma 4 E2B Q4_0 GGUF
    -> Prometheus / Grafana
    -> OpenAI-compatible API validation
    -> evidence summary
```

The purpose of this environment is to validate the common deployment, serving, monitoring, troubleshooting, and evidence path before GPU hardware validation.

## Validation boundary

| Area | Public status | Meaning |
|---|---|---|
| CPU Cloud | **BUILT / E2E VALIDATED** | The recorded CPU prevalidation gates completed with PASS. |
| GPU Cloud | **DESIGNED / HARDWARE VALIDATION PENDING** | GPU hardware, CUDA, GPU Operator, multi-GPU inference, and GPU performance are not claimed as validated. |
| Publication package | **MANUALLY REBUILT** | The component results are from the captured run, but the original evidence collector also recorded a packaging failure. |

`PASS` here means the corresponding validation check passed in the recorded run. It is not a production-readiness, GPU-performance, or multi-node availability claim.

## Navigate the evidence

- [Architecture](./cpu-cloud/overview/architecture.md)
- [Environment](./cpu-cloud/overview/environment.md)
- [Deployment and validation flow](./cpu-cloud/overview/deployment-flow.md)
- [Validation status](./cpu-cloud/overview/validation-status.md)
- [Actual results](./cpu-cloud/overview/actual-results.md)
- [Kubernetes validation](./cpu-cloud/kubernetes/validation.md)
- [LLM validation](./cpu-cloud/llm/validation.md)
- [Sanitized inference summary](./cpu-cloud/llm/inference-summary.json)
- [Monitoring validation](./cpu-cloud/monitoring/validation.md)
- [Windows client integration note](./cpu-cloud/windows-client/validation.md)
- [Technical findings](./cpu-cloud/overview/technical-findings.md)
- [Machine-readable result](./cpu-cloud/validation/result.json)
- [Capture metadata](./cpu-cloud/validation/run-metadata.json)

## Public evidence policy

Only derived summaries are included here. Raw host output, Kubernetes output, environment configuration, credentials, internal URLs, host identity, browser chrome, terminal captures, and model reasoning content are not part of the public package.

The package-level `MANIFEST.sha256` is generated for this directory after the contents are finalized. It is independent from the source run's internal manifest and from the generated candidate under the repository's `STARTLINE_Evidence` directory.
