# Tanzu Supply Chains Component Authoring

Engineering a component requires thinking in layers.

This example will show how to build and test a shell script to be used in a Tekton Task. If you code reaches the level of complexity that you need to run unit test, it's recommended to use a language such as Golang or Python.

- At the bottom most layer you have the step within the Tekton task, which is a shell script. It's recommended to write the script in such a way that it can be executed and tested in isolation without the extra overhead of Tekton. 
- Once the script is running then the Tekton wrapper can be place around it and it can be tested with a pipeline run.
- Once the pipeline run completes successfully it can be wrapped in a component.

The instructions below detail the steps needed to build up these layers to create a simple stateful set based upon the pod spec output of the conventions server.

**Warning** this tutorial uses ytt overlays, so you may want to check out some tutorials on that before continuing.

This example uses simple shell scripts tested on Linux.

The raw yaml and scripts below can be found [here](https://github.com/laidbackware/laidbackware.github.io/tree/main/code-snippits/component-authoring-example).

## Inputs and outputs

The component will expect an input of the pod spec, which is an output from the convention server. An input from the convention server will contain a single file in the root of the workspace called `app-config.yaml`. Below is an abbreviated pod spec, with the 2 sections that will be reused.

```yaml
template:
  spec:
    containers:
    - env:
      - name: JAVA_TOOL_OPTIONS
        value: -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -Dserver.port="8080" -Dserver.shutdown.grace-period="24s"
      image: private.reg/image:tag
...
```

To match the existing workload types and allow it to be used by the sebsequent existing supply chain components, 2 outputs will be created. `oci-yaml-files` containing the base yaml for the package and `oci-ytt-files` which will contain the variables.

The files listed below will be expected by the `carvel-package` component.

```sh
/workspace/oci-yaml-files
|-- appconfig.yaml # contains the base spec

/workspace/oci-ytt-files
|-- web-template-overlays.yaml # contains the overlays needed to replace values in appconfig.yaml
|-- web-template-values.yaml # contains the base values
```

The component will also take a single variable input of the workload name.

## Writing the script

Because the script will require a file structure to be layed out, a wrapper script is needed to first setup a simulated Tekton workspace with a dummy `appconfig.yaml` to replicate a convention component output.

### Simple test wrapper

The outer test wrapper script needs to setup any necessary files and export all environment variables used by the task script.

File `app-config.yaml` is an abbreviated version of a convention component output containing the fields needed to build a K8s resource.

Because the component has 2 outputs, 2 directories need to be passed into the script. `WORKSPACE_YAML` will be used for the `oci-yaml-files` output and `WORKSPACE_YTT` for the `oci-ytt-files` output.

[test-task-script.sh](../../../code-snippits/component-authoring-example/test-task-script.sh)
```sh
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
      image: private.reg/image:tag
EOT

export WORKSPACE_YAML=$TEMP_DIR_YAML
export WORKSPACE_YTT=$TEMP_DIR_YTT
export WORKLOAD_NAME="dummy"

${SCRIPT_DIR}/task-script.sh
```

### Task script

The task script expects 3 environment variables, which were set by the wrapper. `WORKSPACE_YAML` and `WORKSPACE_YTT` represent the workspace paths and `WORKLOAD_NAME` is needed to substitute into the yaml. By make these environment variables it means that the script can be Tekton agnostic and enables running/testing outside Tekton.

`web-template-values.yaml` and `web-template-overlays.yaml` are rendered using Bash to inject the workload name.

The output `appconfig.yaml` needs to be created with ytt because it will be referencing the values from the data source from the input `app-config.yaml`.

[task-script.sh](../../../code-snippits/component-authoring-example/task-script.sh)
```sh
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
```

### More advanced unit testing

Whilst outside the scope of this article, if more advanced testing of Bash scripts are needed, it's recommended to use the [BATS Framework](https://github.com/bats-core/bats-core), which will enable testing of individual functions with assertions.

## Injecting the script into the task

Once the script is working exactly as expected it can be injected to the task spec.

For this script to work the kube context be pointing to a TAP 1.9+ cluster with Tanzu Supply Chains installed.

The script below generates an overlay to inject the variables, gets an image ref from the running cluster that container the necessary dependencies, strips the script from `task.yaml` to remove extra overlays and re-creates `task.yaml` with the injected values.

[render-task.sh](../../../code-snippits/component-authoring-example/render-task.sh)
```sh
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
```

## Testing the Task

To ensure the Tekton Task is setup correctly a dedicated Tekton pipeline can be built to run end-to-end tests.

### Test Pipeline

Similar to the test script the pipeline will run a task to populate the workspace, run the component task, then run a task that validate there is a line containing `kind: StatefulSet` in the correct file.

[test-pipeline.yaml](../../../code-snippits/component-authoring-example/test-pipeline.yaml)
```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-pipeline
spec:
  params:
  - description: Name of the Workload. Used as a default for the Carvel Package secret name.
    name: workload-name
    type: string
    default: "dummy"
  tasks:
    - name: workspace-setup
      taskSpec:
        steps:
          - image: blank
            script: |
              #!/bin/sh

              cat <<EOT >> $(workspaces.shared-data.path)/app-config.yaml
              template:
                spec:
                  containers:
                  - env:
                    - name: JAVA_TOOL_OPTIONS
                      value: -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -Dserver.port="8080" -Dserver.shutdown.grace-period="24s"
                    image: harbor.lab:8443/tap-workload/friday-workload@sha256:cbd7c9d033f3b4a3ed5faf23a02e69bcfc9443ab405c49d9433d9af656b1eedd
              EOT
      workspaces:
        - name: store
          workspace: shared-data

    - name: app-config-stateful
      runAfter:
        - workspace-setup
      params:
      - name: workload-name
        value: $(params.workload-name)
      taskRef:
        name: app-config-stateful
      workspaces:
        - name: shared-data
          workspace: shared-data
        - name: overlay-data
          workspace: overlay-data
    
    - name: test-output
      runAfter:
        - app-config-stateful
      taskSpec:
        steps:
          - image: blank
            script: |
              #!/bin/sh

              grep -Fxq "kind: StatefulSet" $(workspaces.shared-data.path)/appconfig.yaml
      workspaces:
        - name: store
          workspace: shared-data

  workspaces:
    - name: shared-data
      description: Used to store the Conventions PodIntent and generated config files.
    - name: overlay-data
      description: Used to store generated YTT files.
```

### Setting the task images

To populate the image tags run the following commands. It assumes that in `test-pipeline.yaml` the image section of each step is the first line of the step, by searching for `- image:`.

```sh
TASK_IMAGE=$(kubectl get task -n alm-catalog deployer -o jsonpath='{.spec.steps[0].image}')
sed -i "s%- image: .*%- image: ${TASK_IMAGE}%" test-pipeline.yaml
```

### Creating a test PipelineRun

The test PipelineRun will then run through each task.

[test-pipeline-run.yaml](../../../code-snippits/component-authoring-example/test-pipeline-run.yaml)
```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: test-pipeline-run
spec:
  pipelineRef:
    name: test-pipeline
  taskRunTemplate:
    podTemplate:
        securityContext:
          fsGroup: 1000
          runAsUser: 1001
          runAsGroup: 1000
  workspaces:
    - name: shared-data
      volumeClaimTemplate:
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 1Gi
    - name: overlay-data
      volumeClaimTemplate:
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 1Gi
```

## Creating the component


```yaml
```