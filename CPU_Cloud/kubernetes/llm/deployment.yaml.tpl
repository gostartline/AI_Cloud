apiVersion: apps/v1
kind: Deployment
metadata:
  name: __LLM_SERVICE__
  namespace: __LLM_NAMESPACE__
  labels:
    app.kubernetes.io/name: __LLM_SERVICE__
    app.kubernetes.io/part-of: startline-cpu-cloud
    app.kubernetes.io/component: llm
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: __LLM_SERVICE__
  template:
    metadata:
      labels:
        app.kubernetes.io/name: __LLM_SERVICE__
        app.kubernetes.io/part-of: startline-cpu-cloud
    spec:
      automountServiceAccountToken: false
      containers:
        - name: llama-server
          image: __LLM_IMAGE__
          imagePullPolicy: IfNotPresent
          args:
            - --model
            - /models/__MODEL_FILE__
            - --host
            - 0.0.0.0
            - --port
            - "__LLM_PORT__"
            - --ctx-size
            - "__LLM_CONTEXT__"
            - --threads
            - "__LLM_THREADS__"
            - --parallel
            - "__LLM_PARALLEL__"
            - --metrics
          ports:
            - name: http
              containerPort: __LLM_PORT__
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 30
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 5
          resources:
            requests:
              cpu: "2"
              memory: 4Gi
            limits:
              cpu: "3"
              memory: 10Gi
          volumeMounts:
            - name: model
              mountPath: /models
              readOnly: true
      volumes:
        - name: model
          hostPath:
            path: __MODEL_DIR__
            type: Directory
