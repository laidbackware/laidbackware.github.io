# Re-pave a vSphere 7 cluster

This patch will cause all nodes to be created on a vSphere 7 workload cluster.

Commands must be run against the supervisor.

## Find the `machinedeployments` object for your cluster

```sh
kubectl get machinedeployments.cluster.x-k8s.io -n <namespace>
```

```sh
kubectl patch machinedeployments.cluster.x-k8s.io ${TEMPLATE_NAME:?} --type merge -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"date\":\"`date +'%s'`\"}}}}}" -n <namespace>
```