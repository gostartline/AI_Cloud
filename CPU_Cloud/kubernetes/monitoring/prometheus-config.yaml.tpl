apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: __PROMETHEUS_NAMESPACE__
  labels:
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: startline-cpu-cloud
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]
      - job_name: llm
        metrics_path: /metrics
        static_configs:
          - targets: ["__LLM_SERVICE__.__LLM_NAMESPACE__.svc.cluster.local:__LLM_PORT__"]
