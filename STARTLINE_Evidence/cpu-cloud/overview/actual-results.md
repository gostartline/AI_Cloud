# Actual Results

## Recorded run

| Field | Value |
|---|---|
| Run ID | `20260830T090429Z` |
| Capture completion | `2026-08-30T09:04:30Z` |
| Configuration baseline | `cpu-prevalidation-v1.2` |
| Validation phase | `CPU_NON_GPU_PREVALIDATION` |
| Component result | PASS |

## Stack result

The recorded result contains PASS for host precheck, OS baseline, containerd, Kubernetes packages, single-node Kubernetes, model download, CPU LLM server, monitoring, and end-to-end stack validation.

## CPU-only inference point

The latest machine-readable inference summary recorded:

- model family: Gemma 4 E2B
- runtime: llama.cpp server
- finish reason: `stop`
- prompt tokens: `25`
- completion tokens: `89`
- total tokens: `114`
- predicted generation rate: `8.7852 tokens/sec`

This is a measurement from the CPU-only prevalidation environment. It must not be read as GPU performance, a capacity guarantee, or a claim of a high-performance LLM deployment.

The practical client capture used a non-thinking request configuration because extended thinking was too slow for the CPU test. Raw response bodies and model reasoning fields are intentionally omitted from this public package.
