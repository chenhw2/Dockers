FROM chenhw2/xray-plugin:latest as plugin
FROM chenhw2/udp-speeder:latest as us
FROM chenhw2/gost:latest as gost

FROM chenhw2/debian:base
LABEL MAINTAINER="https://github.com/chenhw2/Dockers"

RUN set -ex && cd / \
    && apt update \
    && apt install -y --no-install-recommends iptables openvpn \
    && rm -rf /tmp/* /var/cache/apt/* /var/log/*

COPY --from=gost /usr/bin/gost /usr/bin/
COPY --from=us /usr/bin/udp-speeder /usr/bin/
COPY --from=plugin /usr/bin/xray-plugin /usr/bin/

ENV WS_PATH='/websocket' \
    GOST_ARGS='' \
    MODE=''

EXPOSE 1984/tcp 8488/tcp 8488/udp 8499/udp

ADD entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]
