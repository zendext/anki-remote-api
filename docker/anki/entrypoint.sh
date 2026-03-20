#!/usr/bin/env bash
set -euo pipefail

ANKI_BASE="${ANKI_BASE:-/anki-data}"
PROFILE="${ANKI_PROFILE:-User 1}"
DISPLAY="${DISPLAY:-:1}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-anki}"
ANKI_HOME="/home/anki"
ANKI_USER="anki"
REAL_ANKI="${ANKI_HOME}/.local/share/AnkiProgramFiles/.venv/bin/anki"
LAUNCHER_ANKI="/usr/local/bin/anki"
WAIT_FOR_ANKICONNECT="${WAIT_FOR_ANKICONNECT:-1}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1440x900}"
VNC_DEPTH="${VNC_DEPTH:-24}"
VNC_PASSWORD="${VNC_PASSWORD:-}"

export DISPLAY XDG_RUNTIME_DIR QTWEBENGINE_DISABLE_SANDBOX QTWEBENGINE_CHROMIUM_FLAGS QT_DEBUG_PLUGINS ANKI_NOHIGHDPI HOME="${ANKI_HOME}"
mkdir -p "${XDG_RUNTIME_DIR}" "${ANKI_BASE}" "${ANKI_HOME}/.cache/uv" "${ANKI_HOME}/.local/share/AnkiProgramFiles" "${ANKI_HOME}/.local/share/Anki2"
chown -R ${ANKI_USER}:${ANKI_USER} "${XDG_RUNTIME_DIR}" "${ANKI_BASE}" "${ANKI_HOME}/.cache" "${ANKI_HOME}/.local"
chmod 700 "${XDG_RUNTIME_DIR}"

run_as_anki() {
    su -s /bin/bash -c "$*" "${ANKI_USER}"
}

shell_quote() {
    printf '%q' "$1"
}

cleanup() {
    echo "[entrypoint] shutting down"
    kill "${ANKI_PID:-}" 2>/dev/null || true
    kill "${OPENBOX_PID:-}" 2>/dev/null || true
    kill "${NOVNC_PID:-}" 2>/dev/null || true
    kill "${VNC_PID:-}" 2>/dev/null || true
}
trap cleanup SIGTERM SIGINT

# 1. Virtual desktop
mkdir -p "${ANKI_HOME}/.vnc"
chown -R ${ANKI_USER}:${ANKI_USER} "${ANKI_HOME}/.vnc"
if [[ -n "${VNC_PASSWORD}" ]]; then
    run_as_anki "mkdir -p $(shell_quote "${ANKI_HOME}/.vnc") && printf '%s\n' $(shell_quote "${VNC_PASSWORD}") | vncpasswd -f > $(shell_quote "${ANKI_HOME}/.vnc/passwd") && chmod 600 $(shell_quote "${ANKI_HOME}/.vnc/passwd")"
    VNC_AUTH_ARGS="-rfbauth ${ANKI_HOME}/.vnc/passwd"
else
    echo "[entrypoint] no VNC password set; enabling insecure public VNC for debugging"
    VNC_AUTH_ARGS="--I-KNOW-THIS-IS-INSECURE -SecurityTypes None"
fi

echo "[entrypoint] starting Xvnc on ${DISPLAY} (${VNC_GEOMETRY}x${VNC_DEPTH})"
run_as_anki "dbus-run-session -- sh -lc 'tigervncserver ${DISPLAY} -fg -localhost no -geometry ${VNC_GEOMETRY} -depth ${VNC_DEPTH} ${VNC_AUTH_ARGS}'" > >(sed 's/^/[xvnc] /') 2> >(sed 's/^/[xvnc][stderr] /' >&2) &
VNC_PID=$!
sleep 2

echo "[entrypoint] starting openbox"
run_as_anki "export DISPLAY='${DISPLAY}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' HOME='${ANKI_HOME}' PYTHONFAULTHANDLER='${PYTHONFAULTHANDLER:-1}' RUST_BACKTRACE='${RUST_BACKTRACE:-1}' RUST_LOG='${RUST_LOG:-debug}'; exec openbox-session" > >(sed 's/^/[openbox] /') 2> >(sed 's/^/[openbox][stderr] /' >&2) &
OPENBOX_PID=$!

echo "[entrypoint] starting noVNC on :${NOVNC_PORT} -> localhost:${VNC_PORT}"
websockify --web=/usr/share/novnc/ ${NOVNC_PORT} 127.0.0.1:${VNC_PORT} > >(sed 's/^/[novnc] /') 2> >(sed 's/^/[novnc][stderr] /' >&2) &
NOVNC_PID=$!


# 2. Start Anki
ANKI_LOG="${ANKI_BASE}/anki-startup.log"
run_as_anki "rm -f $(shell_quote "${ANKI_LOG}") && touch $(shell_quote "${ANKI_LOG}")"
if [[ -x "${REAL_ANKI}" ]]; then
    echo "[entrypoint] using installed venv Anki: ${REAL_ANKI}"
    START_CMD="export DISPLAY='${DISPLAY}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' HOME='${ANKI_HOME}' PYTHONFAULTHANDLER='${PYTHONFAULTHANDLER:-1}' RUST_BACKTRACE='${RUST_BACKTRACE:-1}' RUST_LOG='${RUST_LOG:-debug}'; exec '${REAL_ANKI}' --base '${ANKI_BASE}' --profile '${PROFILE}'"
else
    echo "[entrypoint] using launcher bootstrap: ${LAUNCHER_ANKI}"
    START_CMD="export DISPLAY='${DISPLAY}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' HOME='${ANKI_HOME}' PYTHONFAULTHANDLER='${PYTHONFAULTHANDLER:-1}' RUST_BACKTRACE='${RUST_BACKTRACE:-1}' RUST_LOG='${RUST_LOG:-debug}'; exec '${LAUNCHER_ANKI}' --base '${ANKI_BASE}' --profile '${PROFILE}'"
fi
(
    run_as_anki "${START_CMD}"
) > >(sed 's/^/[anki] /' | tee -a "${ANKI_LOG}") \
  2> >(sed 's/^/[anki][stderr] /' | tee -a "${ANKI_LOG}" >&2) &
ANKI_PID=$!

# 4. Wait strategy
if [[ "${WAIT_FOR_ANKICONNECT}" = "0" ]]; then
    echo "[entrypoint] WAIT_FOR_ANKICONNECT=0; virtual desktop ready"
    echo "[entrypoint] noVNC URL: http://localhost:${NOVNC_PORT}/vnc.html"
    wait "${ANKI_PID}"
    exit $?
fi

echo "[entrypoint] waiting for AnkiConnect..."
ANKICONNECT_URL="${ANKICONNECT_URL:-http://localhost:8765}"
MAX_WAIT=120
WAITED=0
until curl -sf "${ANKICONNECT_URL}" -d '{"action":"version","version":6}' > /dev/null 2>&1; do
    if ! kill -0 "${ANKI_PID}" 2>/dev/null; then
        echo "[entrypoint] ERROR: Anki process exited before AnkiConnect became ready" >&2
        if [[ -f "${ANKI_LOG}" ]]; then
            echo "[entrypoint] startup log tail:" >&2
            tail -n 200 "${ANKI_LOG}" >&2 || true
        fi
        exit 1
    fi
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "[entrypoint] ERROR: AnkiConnect did not become ready within ${MAX_WAIT}s" >&2
        if [[ -f "${ANKI_LOG}" ]]; then
            echo "[entrypoint] startup log tail:" >&2
            tail -n 200 "${ANKI_LOG}" >&2 || true
        fi
        exit 1
    fi
    sleep 1
    WAITED=$((WAITED + 1))
done

echo "[entrypoint] AnkiConnect ready (${WAITED}s)"
wait "${ANKI_PID}"
