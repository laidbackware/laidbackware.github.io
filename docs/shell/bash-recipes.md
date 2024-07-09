# Bash Recipes

## Run command with stdin as an input

Kubbectl apply from an inline yaml string.

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: tap-install
EOF
```

## Conditional run command

Run command based on output of another command. 

```sh
set +e
networks="$(docker network inspect kind-tilt 2>&1)"
set -e
if [[ "$networks" == *"network kind-tilt not found"* ]]; then
  docker network create --gateway="100.127.0.1" --ip-range="100.127.0.0/24" --subnet="100.127.0.0/16" kind-tilt
else
  echo "kind-tilt network already exists"
fi
```

## Sed

### Get all on line text after a string

E.g. return value after the first occurrence of `name: ` from a file on Linux.

```sh 
sed -n -e '/name/ {s/.*: *//p;q}' /$HOME/.kube/config
```

### Replace text in a line, keeping before the match

E.g. 

```sh
sed -r 's/(^.*)cheese/\1mice/'
```

## Remove all lines starting with string

E.g. remove all lines starting with "#@".

```sh
cat blah.txt | grep -v "#~"
```

## Check if a URL is available

E.g. check if google.com is contactable. Can be used to check if VPN is connected.

```sh
status_code="$(curl --write-out %{http_code} --silent --output -k /dev/null https://www.google.com)"

if [[ "$status_code" -ne 200 ]] ; then
  echo "You are not connected to the VPN. Please connect and re-run this script"
else
  exit 1
fi
```

## Check if command is in path

E.g. check if ytt is available in the shell.

```sh
if ! [ -x "$(command -v ytt)" ]; then
  echo -e 'ytt CLI not in path.\nSee https://github.com/carvel-dev/ytt' >&2
  exit 1
fi
```

## Do something if command fails

E.g. ff image is not in local registry copy image over.

```sh
if ! docker image inspect ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:${TAP_VERSION} > /dev/null; then
  imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION:-?} --to-repo ${INSTALL_REGISTRY_HOSTNAME:?}/${INSTALL_REPO:?}/tap-packages
fi
```