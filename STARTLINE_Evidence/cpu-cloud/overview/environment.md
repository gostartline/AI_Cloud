# Environment

The following is the sanitized environment profile for the recorded CPU-only prevalidation run.

| Component | Recorded profile |
|---|---|
| Cloud target | Vultr Dedicated CPU |
| Region | Tokyo (declared target metadata) |
| Operating system | Ubuntu 24.04.4 LTS |
| CPU | 4 vCPU; approximately 16 GiB memory class |
| Storage | 240 GB declared target; the precheck recorded approximately 203 GiB free root disk |
| Container runtime | containerd with runc and CNI plugins |
| Orchestrator | Kubernetes v1.35.6, single-node kubeadm cluster |
| CNI | Flannel |
| LLM runtime | llama.cpp server, CPU-only |
| Model | Gemma 4 E2B Q4_0 GGUF |
| Monitoring | Prometheus / Grafana |
| Client | Windows 11 supplementary client capture |

The provider, region, and storage figures are the declared test profile. They are not a claim that the public repository independently verifies a cloud-provider contract or billing record.
