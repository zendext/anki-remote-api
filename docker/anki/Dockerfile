# Anki Desktop + AnkiConnect + Xvfb
# Provides a headless Anki instance accessible via AnkiConnect HTTP API.
FROM debian:bookworm-slim

ARG ANKI_VERSION=25.02
ARG ANKI_PKG=anki-${ANKI_VERSION}-linux-qt6

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    ANKI_BASE=/anki-data \
    ANKICONNECT_VERSION=24.7.31.0

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    wget \
    ca-certificates \
    zstd \
    libglib2.0-0 \
    libgl1 \
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
    python3 \
    python3-sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Anki
RUN wget -q "https://github.com/ankitects/anki/releases/download/${ANKI_VERSION}/${ANKI_PKG}.tar.zst" \
    && tar --use-compress-program=unzstd -xf "${ANKI_PKG}.tar.zst" \
    && cd "${ANKI_PKG}" && ./install.sh \
    && cd .. && rm -rf "${ANKI_PKG}" "${ANKI_PKG}.tar.zst"

# Install AnkiConnect addon
RUN mkdir -p /root/.local/share/Anki2/addons21/AnkiConnect \
    && wget -q "https://github.com/FooSoft/anki-connect/archive/refs/tags/${ANKICONNECT_VERSION}.tar.gz" \
    && tar -xzf "${ANKICONNECT_VERSION}.tar.gz" \
    && cp -r anki-connect-${ANKICONNECT_VERSION}/plugin/* /root/.local/share/Anki2/addons21/AnkiConnect/ \
    && rm -rf anki-connect-${ANKICONNECT_VERSION} "${ANKICONNECT_VERSION}.tar.gz"

# AnkiConnect config: allow connections from API service (same container network)
COPY ankiconnect.json /root/.local/share/Anki2/addons21/AnkiConnect/config.json

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
