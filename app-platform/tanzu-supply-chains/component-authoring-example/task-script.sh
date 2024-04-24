#!/bin/bash

set -euxo pipefail

TEMP_DIR="$(mktemp -d)"

# clean the workspace directory by moving any inputs to the temp directory
mv $WORKSPACE_YAML/* $TEMP_DIR/

cat <<EOT >> ${WORKSPACE_YTT}/web-template-values.yaml
#@data/values-schema
---
#@schema/desc "Used to generate resource names."
#@schema/example "tanzu-java-web-app"
#@schema/validation min_len=1
workload_name: "${WORKLOAD_NAME:?}"

#@schema/desc "Number of repicas."
replicas: 1
EOT

cat <<EOT >> ${WORKSPACE_YTT}/web-template-overlays.yaml
#@ load("@ytt:overlay", "overlay")
#@ load("@ytt:data", "data")
#@ load("@ytt:template", "template")

#@overlay/match by=overlay.subset({"apiVersion":"apps/v1", "kind": "StatefulSet"})
---
spec:
  #@ if data.values.env:
  #@overlay/match missing_ok=True
  #@overlay/replace or_add=True
  replicas: #@ data.values.replicas
  #@ end
EOT

OUTPUT_APPCONFIG=`cat <<EOF
#@ load("@ytt:overlay", "overlay")
#@ load("@ytt:data", "data")
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: "${WORKLOAD_NAME:?}"
spec:
  selector:
    matchLabels:
      app: "${WORKLOAD_NAME:?}"
  serviceName: "${WORKLOAD_NAME:?}"
  replicas: 1
  template:
    metadata:
      labels:
        app: "${WORKLOAD_NAME:?}"
    spec:
      containers:
      - name: "${WORKLOAD_NAME:?}"
        env: #@ data.values.template.spec.containers[0].env
        image: #@ data.values.template.spec.containers[0].image
        ports:
        - containerPort: 80
          name: web
EOF
`

echo "$OUTPUT_APPCONFIG" | ytt -f - --data-values-file ${TEMP_DIR}/app-config.yaml > ${WORKSPACE_YAML}/appconfig.yaml

ls -l ${WORKSPACE_YAML}
ls -l ${WORKSPACE_YTT}