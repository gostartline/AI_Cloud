# Technical Findings

The following findings are retained as concise troubleshooting evidence. Raw logs are excluded because they contain environment-specific host, network, command, and cluster identifiers.

| Finding | Publicly retained conclusion | Evidence basis |
|---|---|---|
| `SCRIPT_DIR` collision | Shared shell-library imports were kept independent from each phase script's `SCRIPT_DIR`; static coverage checks import stability. | CPU scripts and static tests |
| `pipefail` / SIGPIPE (`rc=141`) | An early Kubernetes-package attempt produced `rc=141`; a later attempt passed. Pipeline behavior is treated as an operational failure mode, not ignored output. | Recorded execution log and tests |
| Kubernetes partial state | An early cluster attempt detected unhealthy existing state and stopped instead of resetting it automatically; a later clean validation passed. | Recorded execution log and cluster phase result |
| UFW routed traffic | The final captured firewall state used a Pod-CIDR exception on the CNI interface while retaining a default routed-deny posture. | Sanitized interpretation of captured UFW state and source logic |
| CoreDNS watch / API reachability | CoreDNS watch/readiness errors appeared in raw output; the final cluster phase also recorded Ready CoreDNS and in-cluster DNS validation. The public package keeps this as a troubleshooting caveat, not as a claim that every raw log line was clean. | Captured CoreDNS output and cluster validation |
| Prometheus LLM target | An early stack validation attempt reported the LLM target down; a later attempt recorded the target up and completed successfully. | Recorded execution log and final metrics query |
| LLM reasoning/content mismatch | An early inference validation rejected a response without assistant content. The validator and static tests require actual assistant content and the expected response, rather than accepting reasoning-only output. | Recorded execution log and validator tests |
| Evidence collector output | The source collector recorded failures while writing/verifying `internal/`, `public/`, and the manifest. The package in this directory was rebuilt manually and hashed independently. | Recorded collector log |

The most useful network troubleshooting sequence is therefore:

```text
UFW routed-deny posture
    -> Pod/API reachability issue
    -> CoreDNS watch/readiness symptom
    -> service-DNS / metrics validation impact
    -> explicit rule and validation checks
```

This sequence is presented as a sanitized engineering finding. Host addresses, pod names, raw commands, and unprocessed logs are not public evidence.
