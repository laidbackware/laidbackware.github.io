#!/bin/bash

set -eux

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TASK_IMAGE=$(kubectl get task -n alm-catalog deployer -o jsonpath='{.spec.steps[0].image}')
sed -i "s%- image: .*%- image: ${TASK_IMAGE}%" ${SCRIPT_DIR}/test-pipeline.yaml

