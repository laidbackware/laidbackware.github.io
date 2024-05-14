# Hack Tanzu Supply Chain Tasks to Allow Private Registry

All tasks must be copied to the supply chain names space ahead of time for this procedure to work.

Export the supply chain namespace name:

```sh
export NS_CHAIN="my-supply-chain"
```

Run the following to string substitute in the skip TLS flags. It will get all tasks inside the supply chain namespace, mutate the commands to skip TLS and apply the result back into the supply chain namespace.

```sh
kubectl get tasks -n "${NS_CHAIN:?}" -o yaml | \
  sed 's/push -i/push --registry-verify-certs=false -i/' | \
  sed 's/imgpkg_params -b/imgpkg_params  --registry-verify-certs=false -b/' | \
  sed 's/pull -i/pull --registry-verify-certs=false -i/' | \
  sed 's/krane config "/krane config --insecure "/' | \
  kubectl apply -n "${NS_CHAIN:?}" -f -
```