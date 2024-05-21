# Run pre-start commands with Bosh `os-conf`

The procedure explains how to run a pre-start command on a Bosh instance group. For example to update a config file before a service starts.

In this example it is used to set a flag in the Healthwatch v2 Grafana `defaults.ini` file before Grafana starts. Bosh `runtime-config` will run a pre-start script only on the grafana instance to modify the file before the service is allowed to start.

## Dependencies

- This process assumes an install of Healthwatch v2 installed by Bosh via Opsman.
- [bosh](https://github.com/cloudfoundry/bosh-cli) and [om](https://github.com/pivotal-cf/om) CLIs.
- Connection to the Opsman VM over https and ssh, plus admin credentials and the ssh key.


## Process

1. Connect to the Bosh director
2. Upload the the `os-conf` Bosh release to the director
3. Create a `runtime-config` with a pre-start script
4. Trigger a deployment to have the `runtime-config` injected into the deployment


## Steps

This assumes and existing installation of Healthwatch.

Steps 1-3 could be followed before Healthwatch is installed, allowing it to be added to an installation workflow without triggering a second deployment.

### Step 1 - Connect to the Bosh Director

Export the Opsman credentials:

```sh
OM_USERNAME=admin
OM_TARGET=<opsman-ip/fqdn>
OM_SKIP_SSL_VALIDATION=True # if using self signed
OM_PASSWORD=<password>
```

Choose the connection type depending whether the local machine has network access to the Bosh director.

#### Connect to the Bosh Director directly from local machine

Export the Bosh variables in the shell session buy running:

```sh
eval "$(om bosh-env)"
```

#### Connect to the Bosh Director via Opsman proxy

Export the Bosh variables in the shell session, including the Opsman SSH key for proxying buy running, substituting in the path to the opsman SSH private key:

```sh
eval "$(om bosh-env --ssh-private-key=<path-to-opsman-ssh-key>)"
```

This will make the Bosh CLI proxy commands over SSH through the Opsman VM to the Bosh director.


### Step 3 - Upload the `os-conf` Bosh release

This step will upload the `os-conf` release to the Bosh director.

#### When internet connected

```sh
bosh upload-release --sha1 daf34e35f1ac678ba05db3496c4226064b99b3e4 https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=22.2.1
```

#### When ait gapped

Download the release file from [here](https://bosh.io/releases/github.com/cloudfoundry/os-conf-release).

Transfer the file downloaded file to a machine with Bosh connectivity. `os-conf-release-22.2.1.tgz` was the latest at time of writing.

```sh
bosh upload-release os-conf-release-22.2.1.tgz
```

### Step 3 - Set the `runtime-config`

See [the appendix](#yaml-explanation) for an explanation of the yaml.

Create the following file:

`grafana-runtime-config.yaml`
```yaml
releases:
- name: os-conf
  version: latest
addons:
  - name: grafana-update
    include: 
      instance_groups:
        - grafana
    jobs:
      - name: pre-start-script
        release: os-conf
        properties:
          script: |-
              #!/bin/bash
              sed -i -e 's/viewers_can_edit = false/viewers_can_edit = true/' /var/vcap/packages/grafana/conf/defaults.ini
```

Apply the config to Bosh. Note the update command will create/update, so can always be used.

```sh
bosh update-config --type runtime --name grafana-conf grafana-runtime-config.yaml
```

### Step 4 - Trigger a Bosh deployment

To inject the `runtime-config` a Bosh deployment must be triggered. Simply re-creating the Grafana instance will not be enough, as it will re-deploy using the existing manifest.

Trigger an apply changes and watch the logs to see the injection of the `runtime-config`.

```sh
om apply-changes --product-name p-healthwatch2
```

## Appendix

### Yaml explanation

This section will explain the composition of `grafana-runtime-config.yaml`.

The `release` section tells Bosh to load the latest version of the `os-conf` release.

```yaml
releases:
- name: os-conf
  version: latest
```

`addon` defines a list of jobs to add to instances. The name of the addon is set to `grafana-update`.

`include` specifies the `grafana` instance_group, so that this addon will only apply to the grafana instance groups.

```yaml
addons:
  - name: grafana-update
    include: 
      instance_groups:
        - grafana
```

`jobs` includes a single job. 

The name of the job has to match on of the avaiable [os-conf jobs](https://bosh.io/releases/github.com/cloudfoundry/os-conf-release?version=22.2.1).

The `pre-start-script` will run after releases have been loaded, but before monit starts any services. See [job lifecycle](https://bosh.io/docs/job-lifecycle/) for more details.

`releases` specifies to use the `os-conf` release.

`properties.script` contains a simple shell script which will string substitute `viewers_can_edit = true` into `/var/vcap/packages/grafana/conf/defaults.ini`.

```yaml
    jobs:
      - name: pre-start-script
        release: os-conf
        properties:
          script: |-
              #!/bin/bash
              sed -i -e 's/viewers_can_edit = false/viewers_can_edit = true/' /var/vcap/packages/grafana/conf/defaults.ini
```