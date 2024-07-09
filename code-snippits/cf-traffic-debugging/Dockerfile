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