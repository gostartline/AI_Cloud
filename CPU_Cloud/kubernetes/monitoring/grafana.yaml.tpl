apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: __PROMETHEUS_NAMESPACE__
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: startline-cpu-cloud
    app.kubernetes.io/component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: grafana
  template:
    metadata:
      labels:
        app.kubernetes.io/name: grafana
        app.kubernetes.io/part-of: startline-cpu-cloud
    spec:
      securityContext:
        fsGroup: 472
      automountServiceAccountToken: false
      containers:
        - name: grafana
          image: __GRAFANA_IMAGE__
          imagePullPolicy: IfNotPresent
          env:
            - name: GF_AUTH_ANONYMOUS_ENABLED
              value: "true"
            - name: GF_AUTH_ANONYMOUS_ORG_ROLE
              value: Viewer
            - name: GF_USERS_ALLOW_SIGN_UP
              value: "false"
          ports:
            - name: http
              containerPort: 3000
          readinessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 768Mi
          volumeMounts:
            - name: provisioning
              mountPath: /etc/grafana/provisioning/datasources/datasources.yaml
              subPath: datasources.yaml
              readOnly: true
            - name: data
              mountPath: /var/lib/grafana
      volumes:
        - name: provisioning
          configMap:
            name: grafana-provisioning
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: __PROMETHEUS_NAMESPACE__
  labels:
    app.kubernetes.io/name: grafana
    app.kubernetes.io/part-of: startline-cpu-cloud
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: grafana
  ports:
    - name: http
      port: 3000
      targetPort: http
