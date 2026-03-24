# docker/anki/Dockerfile
# Provides a virtual-desktop Anki instance accessible via VNC/noVNC and optionally AnkiConnect.
FROM debian:bookworm-slim


ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${NO_PROXY}

ARG ANKI_VERSION=25.09.2
ARG ANKI_SERIES=25.09
ARG ANKI_PKG=anki-launcher-${ANKI_SERIES}-linux
ARG ANKI_UID=1000
ARG ANKI_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LIBGL_ALWAYS_SOFTWARE=1 \
    QT_XCB_NO_XI2=1 \
    QTWEBENGINE_DISABLE_SANDBOX=1 \
    QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --no-sandbox" \
    QT_DEBUG_PLUGINS=0 \
    PYTHONFAULTHANDLER=1 \
    RUST_BACKTRACE=1 \
    RUST_LOG=debug \
    ANKI_NOHIGHDPI=1 \
    XDG_RUNTIME_DIR=/tmp/runtime-anki \
    ANKI_BASE=/anki-data \
    HOME=/home/anki \
    VNC_GEOMETRY=1440x900 \
    VNC_DEPTH=24 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080

RUN apt-get update && apt-get install -y --no-install-recommends \
    tigervnc-standalone-server \
    tigervnc-tools \
    openbox \
    novnc \
    websockify \
    xauth \
    x11-xserver-utils \
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
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-glx0 \
    libgl1-mesa-dri \
    mesa-utils \
    libasound2 \
    libpulse0 \
    libatomic1 \
    python3 \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${ANKI_GID} anki \
    && useradd -m -u ${ANKI_UID} -g ${ANKI_GID} -s /bin/bash anki \
    && mkdir -p /anki-data /home/anki/.local/share/Anki2 /home/anki/.cache/uv /home/anki/.local/share/AnkiProgramFiles /tmp/runtime-anki \
    && chown -R ${ANKI_UID}:${ANKI_GID} /home/anki /anki-data /tmp/runtime-anki

RUN wget -q "https://github.com/ankitects/anki/releases/download/${ANKI_SERIES}/${ANKI_PKG}.tar.zst" \
    && zstd -d "${ANKI_PKG}.tar.zst" --stdout | tar -xf - \
    && cd "${ANKI_PKG}" \
    && ln -sf /bin/true /usr/local/bin/xdg-mime \
    && ./install.sh \
    && cd .. && rm -rf "${ANKI_PKG}" "${ANKI_PKG}.tar.zst"

RUN chown -R ${ANKI_UID}:${ANKI_GID} /home/anki/.local

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/anki-data"]
EXPOSE 8765 5901 6080
ENTRYPOINT ["/entrypoint.sh"]
