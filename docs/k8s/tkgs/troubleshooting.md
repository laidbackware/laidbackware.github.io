# Bootstrap troubleshooting

[SSH onto s supervisor node](./admin-access.md) and `sudo -i`.

Check containers with:

```sh
crictl ps
```

Check if the api server is available.

```sh
kubectl get pod -A
```

Check the state of services and the state of cloud init:

```sh
systemctl --type service

less /var/log/cloud-init-output.log
journalctl -xeu  cloud-final
journalctl -xeu  cloud-init
journalctl -xeu  cloud-config
journalctl -xeu  cloud-init-local
```

Check logs on all the nodes with:

```sh
grep -R -i stderr /var/log/pods/*
grep -R -i error /var/log/pods/*
grep -R -i fail /var/log/pods/*
```

Check Kubelet

```sh
systemctl status kubelet  --no-pager --full
journalctl -xeun kubelet
crictl images ls
```