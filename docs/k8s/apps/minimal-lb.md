# Minimal Kubernetes web app + LB

The following yaml will deploy a basic web server and expose it via a load balancer service.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  labels:
    app: test-pod
spec:
  containers:
  - name: test-webserver
    image: k8s.gcr.io/test-webserver:latest
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-svc
spec:
  selector:
    app: test-pod
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```