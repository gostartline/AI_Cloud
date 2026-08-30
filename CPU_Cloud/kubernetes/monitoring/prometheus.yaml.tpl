apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: __PROMETHEUS_NAMESPACE__
  labels:
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: startline-cpu-cloud
    app.kubernetes.io/component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: prometheus
  template:
    metadata:
      labels:
        app.kubernetes.io/name: prometheus
        app.kubernetes.io/part-of: startline-cpu-cloud
    spec:
      securityContext:
        fsGroup: 65534
      automountServiceAccountToken: false
      containers:
        - name: prometheus
          image: __PROMETHEUS_IMAGE__
          imagePullPolicy: IfNotPresent
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
            - --storage.tsdb.retention.time=24h
            - --web.enable-lifecycle
          ports:
            - name: http
              containerPort: 9090
          readinessProbe:
            httpGet:
              path: /-/ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 1Gi
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus/prometheus.yml
              subPath: prometheus.yml
              readOnly: true
            - name: data
              mountPath: /prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-config
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: __PROMETHEUS_NAMESPACE__
  labels:
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/part-of: startline-cpu-cloud
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: prometheus
  ports:
    - name: http
      port: 9090
      targetPort: http
