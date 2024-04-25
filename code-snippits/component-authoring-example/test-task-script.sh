#!/bin/bash

set -eux

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly TEMP_DIR_YAML="$(mktemp -d)"
readonly TEMP_DIR_YTT="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR_YAML" && rm -rf -- "$TEMP_DIR_YTT"' EXIT

cat <<EOT >> ${TEMP_DIR_YAML}/app-config.yaml
template:
  spec:
    containers:
    - env:
      - name: JAVA_TOOL_OPTIONS
        value: -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -Dserver.port="8080" -Dserver.shutdown.grace-period="24s"
      image: harbor.lab:8443/tap-workload/friday-workload@sha256:cbd7c9d033f3b4a3ed5faf23a02e69bcfc9443ab405c49d9433d9af656b1eedd
EOT

export WORKSPACE_YAML=$TEMP_DIR_YAML
export WORKSPACE_YTT=$TEMP_DIR_YTT
export WORKLOAD_NAME="dummy"

${SCRIPT_DIR}/task-script.sh