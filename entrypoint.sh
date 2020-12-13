#!/bin/sh

EXTRA_DOMAINS="$(echo ${EXTRA_DOMAINS} | grep -v 'example.com' | sed 's;[,;]; ;g')"
EXTRA_PROXYS="$(echo ${EXTRA_PROXYS} | grep -v 'example.com')"
ACCEPT_NOSSL=${ACCEPT_NOSSL:-0}

echo "#DOMAIN: ${DOMAIN} ${EXTRA_DOMAINS}"
echo '=================================================='
echo

# MKDIR Init
mkdir -p /etc/ssl/caddy /etc/caddy /data/gitea /var/tmp

web_config() {
host_ip=$(route -n | awk '/^0.0.0.0/ { print $2 }')
echo -n ' '
cat << EOF
{
  timeouts 120s
  gzip

  proxy ${WS_PREFIX} http://${host_ip}:8888 {
    websocket
  }

$( for i in `seq 0 9`; do
cat << FOO
  proxy ${WS_PREFIX}${i} http://${host_ip}:777${i} {
    websocket
  }
FOO
done )

$( echo "${EXTRA_PROXYS}" | tr ',' '\n' | while read it; do
echo $it | grep -q '.' || continue
cat << FOO
  proxy ${it} {
    websocket
  }
FOO
done )

  proxy / http://localhost:8080 {
    except /404.html
    except ${WS_PREFIX}.*
  }
}
EOF
}

# Gitea Init
[ -f /data/gitea/app.ini ] || cat << EOF > /data/gitea/app.ini
[server]
HTTP_PORT    = 8080
DOMAIN       = ${DOMAIN}
ROOT_URL     = https://${DOMAIN}/
DISABLE_SSH  = true
EOF
/usr/bin/gitea web -c /data/gitea/app.ini &

# Caddy Init
cp 404.html /var/tmp/
cat << EOF > /etc/caddy/Caddyfile
:80 {
  redir {
    if {path} not /404.html
    / /404.html
  }
}

$( if echo ${EXTRA_DOMAINS} | grep -q '.'; then
cat << FOO
${EXTRA_DOMAINS} {
  redir {scheme}://${DOMAIN}{uri}
}
FOO
fi )

$( if [ "V$ACCEPT_NOSSL" == "V0" ]; then
  echo -n ${DOMAIN}; web_config
else
  echo -n http://${DOMAIN}; web_config
  echo
  echo -n https://${DOMAIN}; web_config
fi )
EOF

# defualt port 80 443
export CADDYPATH=/etc/ssl/caddy
cat /etc/caddy/Caddyfile
/usr/bin/caddy -agree=true -log stdout -conf=/etc/caddy/Caddyfile -root=/var/tmp
