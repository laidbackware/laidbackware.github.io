# How to access the Tanzu with vSphere Products

## SSH to the Supervisor Cluster nodes

SSH to the vCenter as root and run to get supervisor creds `/usr/lib/vmware-wcp/decryptK8Pwd.py`.

So long as firewall rules allow, the credentials can be saved and the connection made to the supervisor without access to the vCenter.

## SSH to the Guest Cluster nodes

Commands should be run on the supervisor cluster.

SSH commands can be run from anywhere with access to the VMs.

### Using private keys

```sh
kubectl get secret -n <namespace> <cluster name>-ssh -o jsonpath={.data."ssh-privatekey"}  | base64 -d | tee -a privatekey.key
chmod 600 /tmp/privatekey.key
ssh -i /tmp/privatekey.key vmware-system-user@<guest_IP>
```
The private key can be exported and if not should be deleted when finished.

### Using the password

```sh
kubectl get secret -n <namespace> <cluster name>-ssh-password -o jsonpath={.data."ssh-passwordkey"} | base64 -d
ssh vmware-system-user@<guest_IP>
```

### Running commands without kubectl, for debugging

`crictl` mostly mirrors `docker`

```sh
sudo -i
crictl ps # show running containers
crictl logs <container ID> # show container logs
crtictl exec pod <container ID> /bin/sh # exec into a container
```

### Getting kubectl inside a workload cluster control plane node

```sh
sudo -i
export KUBECONFIG=/etc/kubernetes/admin.conf
```

## Legacy TKGS Harbor Admin UI Access

`kubectl` commands must be run from inside a supervisor cluster VM.

```sh
HARBOR_NAMESPACE=$(kubectl get ns | grep registry- | awk '{print $1}')
HARBOR_POD_ID=$(echo $HARBOR_NAMESPACE | sed 's/.*-//')
kubectl get secret -n $HARBOR_NAMESPACE harbor-$HARBOR_POD_ID-controller-registry -o=jsonpath='{.data.harborAdminUsername}' |base64 -d |base64 -d
kubectl get secret -n $HARBOR_NAMESPACE harbor-$HARBOR_POD_ID-controller-registry -o=jsonpath='{.data.harborAdminPassword}' |base64 -d |base64 -d
```