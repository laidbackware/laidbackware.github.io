# Disabling Logging on the Firehose in TP-CF 2.13+

## Background

From TP-CF 2.13 the logging architect changed to allow a [shared nothing topology](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/4.0/tas-for-vms/loggregator-architecture.html#shared-nothing-architecture-2).

![shared-nothing](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/4.0/tas-for-vms/Images/images-architecture-shared-nothing-reference.png)

This change enables all app logs being emitted as syslogs to completely bypass the [Loggregator Firehose architecture](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/4.0/tas-for-vms/loggregator-architecture.html#loggregator-firehose-architecture-1). Whilst this simplification has the potential to reduce the system footprint, there are some considerations before the ["Do not forward app logs to the Firehose"](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/4.0/tas-for-vms/logging-config-opsman.html#:~:text=to%2050%20percent.-,Do%20not%20forward%20app%20logs%20to%20the%20Firehose,-Deactivated%20by%20default) can be ticked on the TAS tile.

## Considerations

All app logs being sent externally must be sent externally must be sent via syslog. None of the partner Nozzle tiles must be in use. E.g. (Azure Nozzle, Nee Relic Nozzle, Splunk Nozzle, Sumo Nozzle).

[App Metrics](https://docs.vmware.com/en/App-Metrics-for-VMware-Tanzu/index.html) currently uses the Firehose for logs which is also a blocker.

Support for Log Cache was added to CF CLI v6.50.0, meaning anyone using the prior versions of the CF CLI will need to upgrade to be able to continue to stream logs via the CF CLI.