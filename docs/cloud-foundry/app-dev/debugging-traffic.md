# Debugging egress traffic

In the situation that there are egress traffic limitation it is necessary for a platform engineer to be able to prove where the issue is and that it is outside of the platform.

Given that CF is able to run OCI images, a container can be build with `tcptraceroute` to enable the debugging of TCP request.

`tcptraceroute` works in similar way to `traceroute` in that it calls out all the intermediate router to get to an endpoint, but will check using a TCP port. It is useful for highlighting the router/fireall that is dropping the traffic.

## Enabling Docker containers

By default CF doesn't allow the pushing of OCI images. It must be abled system-wide with the following command:

```sh
cf enable-feature-flag diego_docker
```

## The Dockefile

This dockerfile can also be found [here](https://github.com/laidbackware/laidbackware.github.io/blob/main/code-snippits/cf-traffic-debugging/Dockerfile).

It is built off the Apache2 httpd debian base image, which will render the static file containing the `tcptraceroute` output.

The inline script runs httpd in the background and then runs an infinite loop of `tcptraceroute` commands against the defined endpoints.

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
  tcptraceroute \${ENDPOINT} \${ENDPOINT_TCP_PORT} 2>&1 | tee -a /usr/local/apache2/htdocs/index.html
  echo "</br></br>" >> /usr/local/apache2/htdocs/index.html
  sleep 5
done
EOF

RUN chmod +x /root/check.sh

ENTRYPOINT ["/root/check.sh"]
```

The image should be built as normal and pushed to a container registry.

```sh
docker image build . -t my-repo/tcp-tst:latest
docker push my-repo/tcp-tst:latest
```

## Pushing the app

This 

```sh
export CF_DOCKER_PASSWORD=<my-registry-password>
cf push tcp-test --docker-image my-repo/tcp-tst:latest \
  --docker-username <my-registry-username> \
  --no-start
cf push tcp-test --docker-image harbor.nas.local:8443/cf/tst:latest --no-start

cf set-env tcp-test ENDPOINT google.com
cf set-env tcp-test ENDPOINT_TCP_PORT 443

cf start tcp-test
```

## Debugging

The app logs will contain the outputs, plus the app can accessed via a web browsers. 

Note that the browsers won't add all character returns, meaning the app logs will give a cleared output.
