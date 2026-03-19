# docker/anki/Dockerfile
# Provides a headless Anki instance accessible via AnkiConnect HTTP API.
FROM debian:bookworm-slim

# Default build/download proxy for this workspace. Can be overridden at build time.
ARG HTTP_PROXY="http://192.168.50.1:23456"
ARG HTTPS_PROXY="http://192.168.50.1:23456"
ARG NO_PROXY="localhost,127.0.0.1,::1"
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${NO_PROXY}

ARG ANKI_VERSION=25.09.2
ARG ANKI_SERIES=25.09
ARG ANKI_PKG=anki-launcher-${ANKI_SERIES}-linux
ARG INSTALL_ANKICONNECT=1
ARG ANKI_UID=1000
ARG ANKI_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    QT_XCB_NO_XI2=1 \
    QTWEBENGINE_DISABLE_SANDBOX=1 \
    QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --no-sandbox" \
    QT_DEBUG_PLUGINS=1 \
    ANKI_NOHIGHDPI=1 \
    XDG_RUNTIME_DIR=/tmp/runtime-anki \
    ANKI_BASE=/anki-data \
    ANKICONNECT_VERSION=23.10.29.0 \
    HOME=/home/anki

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    wget \
    ca-certificates \
    zstd \
    libglib2.0-0 \
    libgl1 \
    libegl1 \
    libopengl0 \
    libgtk-3-0 \
    libxss1 \
    dbus-x11 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxkbcommon-x11-0 \
    libdbus-1-3 \
    libfontconfig1 \
    libnss3 \
    libnspr4 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libxrender1 \
    libxi6 \
    libxtst6 \
    libx11-xcb1 \
    libxcb1 \
    libxcb-util1 \
    libxcb-cursor0 \
    libxcb-shm0 \
    libxcb-glx0 \
    libgl1-mesa-dri \
    mesa-utils \
    libasound2 \
    libpulse0 \
    libatomic1 \
    python3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create fixed non-root runtime user/group.
RUN groupadd -g ${ANKI_GID} anki \
    && useradd -m -u ${ANKI_UID} -g ${ANKI_GID} -s /bin/bash anki \
    && mkdir -p /anki-data /home/anki/.local/share/Anki2 /home/anki/.cache/uv /home/anki/.local/share/AnkiProgramFiles /tmp/runtime-anki \
    && chown -R ${ANKI_UID}:${ANKI_GID} /home/anki /anki-data /tmp/runtime-anki

# Install Anki launcher bundle (new release format)
RUN wget -q "https://github.com/ankitects/anki/releases/download/${ANKI_SERIES}/${ANKI_PKG}.tar.zst" \
    && zstd -d "${ANKI_PKG}.tar.zst" --stdout | tar -xf - \
    && cd "${ANKI_PKG}" \
    && ln -sf /bin/true /usr/local/bin/xdg-mime \
    && ./install.sh \
    && cd .. && rm -rf "${ANKI_PKG}" "${ANKI_PKG}.tar.zst"

# Install AnkiConnect addon (optional for debugging)
RUN if [ "${INSTALL_ANKICONNECT}" = "1" ]; then \
      mkdir -p /home/anki/.local/share/Anki2/addons21/AnkiConnect \
      && wget -q "https://github.com/FooSoft/anki-connect/archive/refs/tags/${ANKICONNECT_VERSION}.tar.gz" \
      && tar -xzf "${ANKICONNECT_VERSION}.tar.gz" \
      && cp -r anki-connect-${ANKICONNECT_VERSION}/plugin/* /home/anki/.local/share/Anki2/addons21/AnkiConnect/ \
      && rm -rf anki-connect-${ANKICONNECT_VERSION} "${ANKICONNECT_VERSION}.tar.gz"; \
    fi

# AnkiConnect config: allow connections from API service (same container network)
COPY ankiconnect.json /tmp/ankiconnect.json
RUN if [ "${INSTALL_ANKICONNECT}" = "1" ]; then \
      mkdir -p /home/anki/.local/share/Anki2/addons21/AnkiConnect \
      && cp /tmp/ankiconnect.json /home/anki/.local/share/Anki2/addons21/AnkiConnect/config.json; \
    fi \
    && rm -f /tmp/ankiconnect.json \
    && chown -R ${ANKI_UID}:${ANKI_GID} /home/anki/.local

# hkey injection script
COPY inject_hkey.py /usr/local/bin/inject_hkey.py

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Anki data lives on a named volume
VOLUME ["/anki-data"]

# AnkiConnect default port
EXPOSE 8765

ENTRYPOINT ["/entrypoint.sh"]
