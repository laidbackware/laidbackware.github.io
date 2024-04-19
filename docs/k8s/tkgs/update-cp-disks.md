# How to update the control plane disks of a workload cluster on vSphere with Tanzu

The docs explains how to expand the disk of a vSphere with Tanzu control plane VMs in place.

**<span style="color:red">THIS PROCEDURE IS NOT SUPPORTED BY VMWARE BY BROADCOM AND MUST BE USED WITH CAUTION! THE AUTHOR CANNOT BE HELD RESPONSIBLE FOR ANY ISSUES.</span>**

**<span style="color:red">Running without the update validation webhook is risky as no control plane update actions will be validated, so should be done for the minimum amount of time.</span>.**

## Connect to a Supervisor VM

SSH into the vCenter as root and enter a shell.

Run:
```sh
/usr/lib/vmware-wcp/decryptK8Pwd.py
```

SSH into the IP address provided by the script output as the root user, using the password provided.

## On a supervisor VM

Run:
```sh
kubectl get ValidatingWebhookConfiguration capi-kubeadm-control-plane-validating-webhook-configuration -o yaml > cp-hook-org.yml
cp cp-hook-org.yml cp-hook-upd.yml
kubectl get ValidatingWebhookConfiguration vmware-system-tkg-validating-webhook-configuration -o yaml > tkg-hook-org.yml
cp tkg-hook-org.yml tkg-hook-upd.yml
```

Edit `cp-hook-upd.yml` and find the object under `webhooks:` with `name: validation.kubeadmcontrolplane.controlplane.cluster.x-k8s.io` (this was the first webhook on my 8.0 update 2 system) then
remove `- UPDATE` line under `rules[0].operations`.

Edit `tkg-hook-upd.yml` and find the object under `webhooks:` with `name: default.validating.tanzukubernetescluster.run.tanzu.vmware.com` (this was the last webhook on my 8.0 update 2 system) then
remove `- UPDATE` line under `rules[0].operations`.

Run:
```sh
kubectl apply -f cp-hook-upd.yml
kubectl apply -f tkg-hook-upd.yml
```

## Updating workload cluster via Supervisor manifest

On a standard linux machine with a normal connection to the supervisor

Now it is possible to update the control plane disks. Be careful to not make any other changes.

## Updating Class based workload clusers via TMC 

Instructions use the Tanzu CLI.

Export the existing cluster config to yaml:
```sh
tanzu management-cluster cluster get <cluster_name> -p <supervisor_namesapce> -m <tmc_supervisor_name> -o yaml > cluster_spec.yaml
```

Remove the "meta" and "status" sections.

Under spec.topology.variables add the following (update the mount, storageClass and sizes as necessary):
```yaml
spec:
  topology:
    variables:
    - name: controlPlaneVolumes
      value:
      - capacity:
          storage: 30G
        mountPath: /var/lib/containerd
        name: containerd
        storageClass: tkgs-storage-policy
      - capacity:
          storage: 30G
        mountPath: /var/lib/kubelet
        name: kubelet
        storageClass: tkgs-storage-policy
```

## Revert on completion!!!!

Once finished, revert the changes on the supervisor by addding the `- UPDATE` lines that were removed at the start.

You can re-apply the original files by SSHing back to the same supervisor node, which should happen automatically following the connection procedure. 

Run:
```sh
kubectl apply -f cp-hook-org.yml
kubectl apply -f tkg-hook-org.yml
```

If for any reason you are not able to access the original yaml files you can follow the process in reverse by adding the relevant lines.