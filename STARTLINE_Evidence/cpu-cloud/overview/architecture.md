# Architecture

## Access and serving path

```text
Windows Client
    |
    | SSH tunnel / local forwarding
    v
Ubuntu CPU VM
    |
    v
Single-node Kubernetes
    |
    v
Kubernetes Service
    |
    v
llama.cpp server
    |
    v
Gemma 4 E2B Q4_0 GGUF
    |
    v
OpenAI-compatible API response
```

The client captures used a locally forwarded endpoint. The public package records the integration path without publishing the endpoint, host, user, or raw terminal command.

## Monitoring path

```text
llama.cpp metrics endpoint
    |
    v
Prometheus scrape
    |
    v
Grafana health / visualization
```

The final validation summary records Prometheus readiness, an LLM target reported as up, and Grafana health.
