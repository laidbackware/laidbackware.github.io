# Minimal Component Example

The example below is a hello world component that does not have any input/outputs, only a single variable to print inside the container.

The raw yaml can be found [here](https://github.com/laidbackware/laidbackware.github.io/tree/main/code-snippits/hello-component-example).

## Component definition

The variable `who-dis` is passed from the workload into the `Component`, to the Pipeline and finally the `Task`. At execution time the WorkloadRun will create a `Stage` for each `Component`. The `Stage` will create `Resumptions` and `PipelineRuns`, with the `PipelineRun` creating `TaskRuns`.

Whilst the `Task` could be written inline inside the pipeline, externalising it enables testing of the `Task` separately if needed.

`component.yaml`
```yaml
---
apiVersion: supply-chain.apps.tanzu.vmware.com/v1alpha1
kind: Component
metadata:
  labels:
    supply-chain.apps.tanzu.vmware.com/catalog: hello-component
  name: hello-0.0.1
spec:
  config:
  - path: spec.who-dis
    schema:
      description: |
        String input to be printed after "Hello "
      type: string
  description: Outputs hello <who-dis>
  pipelineRun:
    params:
    - name: who-dis
      value: $(workload.spec.who-dis)
    pipelineRef:
      name: hello-pipeline
    taskRunTemplate:
      podTemplate:
        securityContext:
          fsGroup: 1000
          runAsGroup: 1000
          runAsUser: 1001
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: hello-pipeline
spec:
  params:
  - description: Input string
    name: who-dis
    type: string
  tasks:
    - name: hello-there
      params:
      - name: who-dis
        value: $(params.who-dis)
      taskRef:
        name: hello-task
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: hello-task
spec:
  params:
  - name: who-dis
    type: string
  steps:
    - name: echo
      image: alpine
      script: |
        #!/bin/sh
        set -e
        echo "Hello $(params.who-dis)"
```
Apply the component.

```sh
kubectl apply -f component.yaml
```

## Supply Chain Spec

The following yaml creates a supply chain against the component.

`supply-chain.yaml`
```yaml
apiVersion: supply-chain.apps.tanzu.vmware.com/v1alpha1
kind: SupplyChain
metadata:
  name: hello.example.tanzu-0.0.1
spec:
  defines: # Describes the workload
    kind: HelloApp
    plural: helloapps
    group: example.tanzu
    version: v1alpha1
  stages: # Describes the stages
    - name: hello
      componentRef: # References the components
        name: hello-0.0.1
```

Create and check the supply chain is ready.

```sh
kubectl apply -f supply-chain.yaml
kubectl get supplychain hello.example.tanzu-0.0.1
```

## Workload Spec

The following yaml creates a workload against the supply chain:

`workload.yaml`
```yaml
apiVersion: example.tanzu/v1alpha1
kind: HelloApp
metadata:
  name: hello-fred
spec:
  who-dis: fred
```

## Running the workload

This example will deploy everything into the same namespace for simplicity. Under normal operations the supply chain and workload would be deployed into separate namespaces.

Apply the workload.

```sh
tanzu workload create -f workload.yaml
```

Query its state.

```sh
tanzu workload get hello-fred
```

This will automatically trigger a workload run which can be monitored with the following commands. If the supply chain has inputs/outputs they can be queried here under `status.stages` using `kubectl`.

```sh
tanzu workload run get $(kubectl get helloappruns.example.tanzu \
  -o jsonpath='{.items[0].metadata.name}')

kubectl describe helloappruns.example.tanzu

kubectl get helloappruns.example.tanzu -o yaml
```

## Debugging

From TAP 1.9 the components will run in the supply chain namespace, which will be separate from the workload namespace. Under normal operation this will prevent the end user from querying Tekton resources and `pods` of the `stages` in the supply chain namespace for security reasons. If the end user needs to see workload run logs they can use the following command:

```sh
tanzu workload logs hello-fred
```

The output of the command can be limited using the following syntax:

```sh
tanzu workload logs NAME --since 1h
tanzu workload logs NAME --since 1h --namespace default --run runname
```
### Advanced debugging

With access to the supply chain namespace the following commands are available.

```sh
kubectl get stage
kubectl tree stage <stage-name>
kubectl get/describe pipeline
kubectl get/describe pipelinerun
kubectl get/describe task
kubectl get/describe taskrun
```