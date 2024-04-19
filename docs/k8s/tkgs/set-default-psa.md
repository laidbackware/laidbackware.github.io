# Set default PSA on vSphere with Tanzu 1.26+ clusters

From TKR 1.26 and above vSphere with Tanzu changed the default [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) (PSA) level to enforced, meaning that each namespace must be labelled to relax the policy. The instructions on this page explain how to create a custom cluster class from the default class which sets the default PSA level to audit.

## Warning
Taken from the vSphere with Tanzu docs.

> "Custom ClusterClass is an experimental Kubernetes feature per the upstream Cluster API documentation. Due to the range of customizations available with custom ClusterClass, VMware cannot test or validate all possible customizations. Customers are responsible for testing, validating, and troubleshooting their custom ClusterClass clusters. Customers can open support tickets regarding their custom ClusterClass clusters, however, VMware support is limited to a best effort basis only and cannot guarantee resolution to every issue opened for custom ClusterClass clusters. Customers should be aware of these risks before deploying custom ClusterClass clusters in production environments."

Given the statement above and the fact that a cluster cannot currently be switched between cluster classes, it is not recommended to use custom cluster classes.

The procedure is based on the {vSphere docs](https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-with-tanzu-tkg/GUID-EFE7DB40-8748-42B5-9694-DBC21F9FB76A.html), which you should always reference to check for changes.

## Procedure

### Step 1 - Copy the default ClusterClass
Export the variables to match your environment.

```sh
export NS="ns1"
export CCC_NAME="my-cc"
```

Export the default ClusterClass, strip unnecessary fields and update the name.
```sh
kubectl -n $NS get clusterclass tanzukubernetescluster -o yaml > ccc.yaml
sed -i '/creationTimestamp:/d' ccc.yaml && sed -i '/generation:/d' ccc.yaml && \
 sed -i '/resourceVersion:/d' ccc.yaml && sed -i '/uid:/d' ccc.yaml && \
 sed -i '/resourceVersion:/d' ccc.yaml
sed -i "s/  name: tanzukubernetescluster/  name: ${CCC_NAME}/g" ccc.yaml
```

### Step 2 - Modify the custom ClusterClass
It's recommended to manually edit the file to set policy, but automated step are listed below.

- Open ccc.yaml in your favourity editor.
- Search for `controlPlaneFilesAdmissionConfigurationk8s126` and scroll up to see the `AdmissionConfiguration` template.
- Modify the yaml to set your policy by updating the section `plugins.0.configuration.defaults`. Scrolling up 30 lines will show the K8s 1.25 policy which does not enforce.

#### Automated steps to replace out the fields of the K8s 1.25 policy.

Use with caution as this was only tested with 1.26.

```sh
sed -i -E 's/enforce: "restricted"/warn: "restricted"\n                      warn-version: "latest"/' ccc.yaml
sed -i -E 's/enforce-version: "latest"/audit: "restricted"\n                      audit-version: "latest"/' ccc.yaml
```

### Step 3 - Apply the custom ClusterClass to any namespace 
The ClusterClass to any namespaces where it is needed.

```sh
export TARGET_NS="ns2"
sed -i "s/namespace: .*/namespace: ${TARGET_NS}/g" ccc.yaml
kubectl apply -f ccc.yaml
```

### Step 4 - Create clusters using the custom ClusterClass
Add the following section to your ClusterClass yamls
```yaml
spec:
  topology:
    class: <custom cluster class name>
```