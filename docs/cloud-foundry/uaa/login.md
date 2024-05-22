# UAA Login to Tanzu products

This doc explains how to use the Golang based [uaa-cli](https://github.com/cloudfoundry/uaa-cli) to log into Tanzu products.

## Dependencies

- [uaa-cli](https://github.com/cloudfoundry/uaa-cli)
- [om](https://github.com/pivotal-cf/om) CLI
- [jq](https://jqlang.github.io/jq/download/)
- Connection to the Opsman VM over https/ssh, uaa over port 84434, Opsman admin credentials and the ssh key.

## Set Opsman environment vars

```sh
OM_USERNAME=admin
OM_TARGET=<opsman-ip/fqdn>
OM_SKIP_SSL_VALIDATION=True # if using self signed
OM_PASSWORD=<password>
```

## Logging in to Bosh UAA

`om bosh-env` can be used to populate the `BOSH_` environment variables, as it will also get the Bosh director IP address.

```sh
eval "$(om bosh-env)"
uaa target "https://${BOSH_ENVIRONMENT}:8443" --verbose -k
uaa get-client-credentials-token ops_manager -s "${BOSH_CLIENT_SECRET}"
```

## Logging in to TAS UAA

The IP address of the TAS UAA servers must be exported as `TAS_UAA_ADDRESS`. 

To find the IP address go to the TAS tile in the Opsman UI, Status, then find one of 

E.g.

```sh
export TAS_SYS_DOMAIN="sys.192.168.1.229.nip.io"
```

```sh
UAAC_SECRET="$(om -k credentials --product-name cf \
  --credential-reference .uaa.admin_client_credentials --format=json |jq -r '.password')"
uaa target https://uaa.${TAS_UAA_ADDRESS} --skip-ssl-validation
uaa get-client-credentials-token admin -s $UAAC_SECRET
```

## Logging in to TKGI UAA

The IP address of the TKGI API servers must be exported as `TKGI_ADDRESS`.

To find the IP address go to the TKGI tile in the Opsman UI, Status, then the TKGI API server.

E.g.

```sh
export TKGI_ADDRESS="192.168.0.10"
```

```sh
UAAC_SECRET=$(om -k credentials --product-name pivotal-container-service \
  --credential-reference .properties.pks_uaa_management_admin_client --format=json | yq r - secret | tr -d '"')
uaa target https://${TKGI_ADDRESS}:8443 --skip-ssl-validation
uaa get-client-credentials-token admin -s $UAAC_SECRET
```