apiVersion: v1
kind: Service
metadata:
  name: __LLM_SERVICE__
  namespace: __LLM_NAMESPACE__
  labels:
    app.kubernetes.io/name: __LLM_SERVICE__
    app.kubernetes.io/part-of: startline-cpu-cloud
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: __LLM_SERVICE__
  ports:
    - name: http
      port: __LLM_PORT__
      targetPort: http
