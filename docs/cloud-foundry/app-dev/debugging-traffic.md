# Debugging egress traffic

In the situation that there are egress traffic limitation it is necessary for a platform engineer to be able to prove where the issue is and that it is outside of the platform.

Given that TAS is able to run OCI images, a container can be build with `tcptraceroute` to enable the debugging of TCP request.

## Enabling Docker containers

By default CF doesn't allow the pushing of OCI images. It must be abled system-wide with the following command:

```sh
cf enable-feature-flag diego_docker
```

## The Dockefile

This dockerfile can also be found here.

```sh
FROM httpd:bookworm

RUN set -xe \
    && echo "****** Install packages with apt ******" \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt update \
    && apt upgrade -y \
    && apt-get install -y tcptraceroute \
    && rm -Rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && rm -rf /tmp/* \
    && apt-get clean

RUN cat <<EOF >> /root/check.sh
#!/bin/bash
set -eu
if [ -z \${ENDPOINT+x} ] || [ -z \${ENDPOINT_TCP_PORT+x} ]; then 
  echo "You must set ENDPOINT and ENDPOINT_TCP_PORT environment variabels"
  exit 1
fi

rm -f /usr/local/apache2/htdocs/index.html
httpd-foreground &

while true; do 
  tcptraceroute \${ENDPOINT} \${ENDPOINT_TCP_PORT} | tee -a /usr/local/apache2/htdocs/index.html
  echo "</br></br>" >> /usr/local/apache2/htdocs/index.html
  sleep 5
done
EOF

RUN chmod +x /root/check.sh

ENTRYPOINT ["/root/check.sh"]
```


```sh
cf push tst --docker-image harbor.nas.local:8443/cf/tst:latest \
  --var ENDPOINT='google.com' \
  --var ENDPOINT_TCP_PORT='443' \
  --health-check-type process


cf push tst --docker-image harbor.nas.local:8443/cf/tst:latest --var "ENDPOINT=google.com" --var "ENDPOINT_TCP_PORT=443"
```