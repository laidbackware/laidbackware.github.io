# Relocating VMs in vSphere

The procedure will describe how to relocate standard VMs from one cluster to another, between vCenters if necessary.

The author cannot take responsibiliy for any issues that could result from making this change. It is recommended to test in a lab environment and check with Broadcom support before rolling out in production.

This process has been tested using the Harbor tile and has not been tested against service instance tiles, such as data services or TKGI.


## Requirements

- This process was tested using Opsman 3.0.33.
- It is strongly recommended to use BBR to backup the director and any tiles which will be changed
- There must be a shared datastore that exists on both the source and target cluster
  - Both source and target datastore MUST have the SAME name
- The network must be available on the source and target clusters
  - Both source and target port group MUST have the SAME name.
- Tested with NSX being disabled in the vCenter config. If NSX is enabled, then extra testing would be required!


## Procedure

### Move the disks to the shared datastore

This step upload the stemcell to the new datastore, re-create the VMs with ephemeral snapshots from the new datastore, attach new disks from the new datastores to copy persistent data and finally detach the source persistent disk.

- Update the persistent disk and ephemeral disk on the Bosh director "vCenter Config" tab to the migration datastore
- On the "Director Config" tab check `Recreate VMs deployed by the BOSH Director`
- Apply changes to move the Bosh director and all non-service instance VMs to the new disk


### Recreate all the VMs on the target cluster

- Add the target cluster as an availability zone (if necessary add the target vCenter, taking care to specify the correct datastores)
- Edit the required networks on the Bosh "Create Networks" page, to add the new availability zone
- On the Opsman VM edit `/var/tempest/workspaces/default/deployments/bosh-state.json` and remove the `stemcells` section to force a re-upload
- On the "Director Config" tab check `Recreate VMs deployed by the BOSH Director` (this gets cleared after the previous successful apply changes).
- (If a static IP is define on the Harbor deployment) Remove it by setting it to blank.
- Enable [Opsman Advanced mode](https://knowledge.broadcom.com/external/article?articleNumber=293516)
- Update the assigned availibility zones of the Bosh director and any tiles that need to be moved
- Cleanly shut down the Bosh director (not any other VMs)
- Apply changes
- Disable [Opsman Advanced mode](https://knowledge.broadcom.com/external/article?articleNumber=293516) or wait for it to timeout
- (If a static IP is define on the Harbor deployment) add it back again and apply changes.


### Tidy Up

- On the source cluster remove the Bosh director VM from the inventory
- Update the persistent disk and ephemeral disk on the Bosh director "vCenter Config" tab to the target datastore
- On the "Director Config" tab check `Recreate VMs deployed by the BOSH Director`
- Apply changes to move the Bosh director and all non-service instance VMs to the new disk