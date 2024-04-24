#!/bin/bash

set -eux

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

readonly TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

# cp ${SCRIPT_DIR}/task.yaml-template $TEMP_DIR/task.yaml

TASK_IMAGE=$(kubectl get task -n alm-catalog deployer -o jsonpath='{.spec.steps[0].image}')

OVERLAY=`cat <<EOF >> ${TEMP_DIR}/overlay.yaml
#@ load("@ytt:overlay", "overlay")
#@ load("@ytt:data", "data")

#@overlay/match by=overlay.subset({"apiVersion":"tekton.dev/v1", "kind": "Task"})
---
spec:
  steps:
    #@overlay/match by=overlay.index(0)
    - image: #@ data.values.task_image
      script: #@ data.values.script
EOF
`

# Strip script to remove inline overlays
sed -n -e '/  script:/{' -e 'p' -e ':a' -e 'N' -e '/  stepTemplate:/!ba' -e 's/.*\n//' -e '}' \
  -e 'p' ${SCRIPT_DIR}/task.yaml > ${TEMP_DIR}/task.yaml

ytt -f ${TEMP_DIR}/task.yaml -f ${TEMP_DIR}/overlay.yaml \
  --data-value-file script=${SCRIPT_DIR}/task-script.sh \
  --data-value task_image=${TASK_IMAGE} > ${SCRIPT_DIR}/task.yaml
