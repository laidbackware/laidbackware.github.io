# Tanzu Supply Chains Component Architecture

TAP 1.8 introduced [Tanzu Supply Chains](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.9/tap/supply-chain-about.html) as the next gen replacement for cartographer.

In summary Tanzu Supply Chains are a wrapped for Tekton, which allow platform and DevOps engineers to easily create APIs for develops to create their workloads.

In it's simplest form a platform engineer can create a supplychain with ~20 lines of yaml using the out of the box (OOB) supply chain components. See [the tutorial](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.9/tap/supply-chain-platform-engineering-tutorials-my-first-supply-chain.html#generate-a-supplychain-2) to generate a supply chain using the CLI.

If functionality is needed beyond the OOB components, then you will need to create a custom component.

## Declarative API and Versioning



### Variables and Types


## Separation of Concerns

Components are designed to be single function and modular, meaning that as the catalogue grows, components can easily be plugged together. For example the the only component that pushes configuration to Git is the `git-writer-1.0.0` component. This is so that the logic exists once.

## Inputs and Outputs

See the [Component Architecture](./component-architecture.md) section for a detailed description.

