# Asterisk 22 LTS built from source — doubles as the install-chapter worked example.
# Pinned for reproducibility; bump ASTERISK_VERSION deliberately.
FROM debian:12-slim

ARG ASTERISK_VERSION=22.10.0
ENV DEBIAN_FRONTEND=noninteractive

# Build + runtime dependencies. We use bundled jansson and pjproject so the SIP
# stack (PJSIP) is version-matched to Asterisk and we need fewer apt packages.
# libsrtp2-dev + (websocket is core) are included so SRTP/WebRTC build for later chapters.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates pkg-config \
        libedit-dev libxml2-dev libsqlite3-dev uuid-dev libssl-dev \
        libsrtp2-dev libcurl4-openssl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
# NOTE: releases/, not the top-level asterisk/ directory. The top level holds
# only the newest point release — when 22.10.1 shipped, the 22.10.0 URL became
# a 404 and this build broke for every student mid-lab. releases/ is permanent.
RUN wget -q "https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz" \
    && tar xzf "asterisk-${ASTERISK_VERSION}.tar.gz" \
    && rm "asterisk-${ASTERISK_VERSION}.tar.gz"

WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}
RUN ./configure --with-jansson-bundled --with-pjproject-bundled \
    && make menuselect.makeopts \
    # ensure SRTP + websocket transport available for the WebRTC chapter
    && menuselect/menuselect --enable res_srtp --enable res_http_websocket menuselect.makeopts \
    && make -j"$(nproc)" \
    && make install \
    && make install-logrotate \
    && ldconfig

# core sounds (hello-world, demo-echotest) come with the default sound packages.
RUN make -C /usr/src/asterisk-${ASTERISK_VERSION} install >/dev/null 2>&1 || true

# Configs are bind-mounted from ./asterisk/etc at runtime (editable without rebuild).
EXPOSE 5060/udp 10000-10100/udp
CMD ["asterisk", "-f", "-vvv"]
