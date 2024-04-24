# Minimal Component Example

The example below is a hello world component that does not have any input/outputs.

The variable `who-dis` is passed from the workload into the Component, to the Pipeline and finally the Task. At execution time the WorkloadRun will create a Stage for each Component. The Stage will create Resumptions and PipelineRuns, with the PipelineRun creating TaskRuns.

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

## Supply Chain Spec

The following yaml creates a supply chain against the component.

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

## Workload Spec

The following yaml creates a workload against the supply chain:

```yaml
apiVersion: example.tanzu/v1alpha1
kind: HelloApp
metadata:
  name: hello-fred
spec:
  who-dis: fred
```

This will then trigger a workload run.