#!/bin/sh

XRAY_CONFIG=/etc/xray.d/server.json
XRAY_SSL_PORT=${XRAY_SSL_PORT:-443}
XRAY_FALLBACK_PORT=${XRAY_FALLBACK_PORT:-80}
XRAY_FALLBACK_ADDR=${XRAY_FALLBACK_ADDR:-127.0.0.1}
WS_PORT=8080
WS_PATH=${WS_PATH:-/websocket}
ACME_PREFIX=${ACME_PREFIX:-/etc/ssl/caddy/acme/acme-v02.api.letsencrypt.org/sites}
ACME_DOMAIN=${ACME_DOMAIN:-example.org}

convertClients() {
  echo $1 | sed 's_;_\n_g' | while read user; do
  uuid=$(echo -n $user | sed 's_:.*__g')
  email=$(echo -n $user | sed 's_.*:__g')
  echo '{}' | jq ".|{id:\"$uuid\",email:\"$email\",flow:\"xtls-rprx-direct\"}"
  echo ','
  done
}

genJsonClients() {
cat <<EOF | sed '/==TOD==/d' | jq '.'
[
  $(convertClients $1)==TOD==
]
EOF
}

# Xray config Init
cat <<EOF | jq '.' | tee $XRAY_CONFIG
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "protocol": "dokodemo-door",
      "port": 1234,
      "settings": {
        "address": "${XRAY_FALLBACK_ADDR}",
        "port": ${XRAY_FALLBACK_PORT},
        "network": "tcp",
        "timeout": 10
      }
    },
    {
      "port": ${XRAY_SSL_PORT},
      "protocol": "vless",
      "settings": {
        "clients": $(genJsonClients $USERS),
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 1234
          },
          {
            "path": "${WS_PATH}",
            "dest": $((WS_PORT+1)),
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "${ACME_PREFIX}/${ACME_DOMAIN}/${ACME_DOMAIN}.crt",
              "keyFile": "${ACME_PREFIX}/${ACME_DOMAIN}/${ACME_DOMAIN}.key"
            }
          ]
        }
      }
    },
    {
      "port": ${WS_PORT},
      "protocol": "vless",
      "settings": {
        "clients": $(genJsonClients $USERS),
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "${WS_PATH}"
        }
      }
    },
    {
      "port": $((WS_PORT+1)),
      "protocol": "vless",
      "settings": {
        "clients": $(genJsonClients $USERS),
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "${WS_PATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

/usr/bin/xray run -c $XRAY_CONFIG
