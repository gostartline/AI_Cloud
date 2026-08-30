# Deployment and Validation Flow

The CPU implementation is organized as an ordered deployment path. The source scripts remain in `CPU_Cloud/scripts`; this public package maps the path to the recorded validation result without copying raw execution logs.

| Order | Source phase | Public interpretation | Recorded result |
|---:|---|---|---|
| 1 | `00_bootstrap.sh` | Install prerequisites required by later phases | PASS marker |
| 2 | `00_precheck.sh` | Check the declared host baseline | PASS |
| 3 | `01_os_baseline.sh` | Configure OS and Kubernetes kernel prerequisites | PASS |
| 4 | `02_containerd.sh` | Install containerd, runc, CNI, and CRI support | PASS |
| 5 | `03_kubernetes_packages.sh` | Install the pinned Kubernetes packages | PASS |
| 6 | `04_single_node_cluster.sh` | Create the kubeadm cluster, networking, and DNS checks | PASS |
| 7 | `download_model.sh` | Download and verify the pinned GGUF artifact | PASS |
| 8 | `05_llm_server.sh` | Deploy the CPU llama.cpp service | PASS |
| 9 | `06_monitoring.sh` | Deploy Prometheus and Grafana | PASS |
| 10 | `07_validate_stack.sh` | Check health, chat completion, metrics, and monitoring | PASS |
| 11 | `99_collect_evidence.sh` | Assemble internal and public evidence packages | **Packaging failure recorded** |

This distinction matters: the infrastructure and stack validation gates are PASS, while the original collector run is not represented as a clean packaging success.
