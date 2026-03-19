#!/usr/bin/env bash
set -euo pipefail

ANKI_BASE="${ANKI_BASE:-/anki-data}"
PROFILE="${ANKI_PROFILE:-User 1}"
PREFS_DB="${ANKI_BASE}/prefs21.db"
DISPLAY="${DISPLAY:-:99}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-anki}"
ANKI_HOME="/home/anki"
ANKI_USER="anki"
REAL_ANKI="${ANKI_HOME}/.local/share/AnkiProgramFiles/.venv/bin/anki"
LAUNCHER_ANKI="/usr/local/bin/anki"
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

# ── 1. Start Xvfb ──────────────────────────────────────────────────────────────
echo "[entrypoint] starting Xvfb on ${DISPLAY}"
Xvfb "${DISPLAY}" -screen 0 1024x768x24 -ac &
XVFB_PID=$!
sleep 1

# ── 2. Inject sync hkey ────────────────────────────────────────────────────────
if [[ -n "${ANKI_SYNC_HKEY:-}" ]]; then
    echo "[entrypoint] injecting sync hkey into prefs21.db"
    run_as_anki "python3 /usr/local/bin/inject_hkey.py $(shell_quote "${PREFS_DB}") $(shell_quote "${PROFILE}") $(shell_quote "${ANKI_SYNC_HKEY}")"
else
    echo "[entrypoint] ANKI_SYNC_HKEY not set — skipping sync configuration"
fi

# ── 3. Start Anki ──────────────────────────────────────────────────────────────
echo "[entrypoint] starting Anki (profile: ${PROFILE})"
ANKI_LOG="${ANKI_BASE}/anki-startup.log"
run_as_anki "rm -f $(shell_quote "${ANKI_LOG}") && touch $(shell_quote "${ANKI_LOG}")"
chown ${ANKI_USER}:${ANKI_USER} "${ANKI_BASE}" || true
if [[ -x "${REAL_ANKI}" ]]; then
    echo "[entrypoint] using installed venv Anki: ${REAL_ANKI}"
    START_CMD="export DISPLAY='${DISPLAY}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' HOME='${ANKI_HOME}'; exec '${REAL_ANKI}' --base '${ANKI_BASE}' --profile '${PROFILE}'"
else
    echo "[entrypoint] using launcher bootstrap: ${LAUNCHER_ANKI}"
    START_CMD="export DISPLAY='${DISPLAY}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' HOME='${ANKI_HOME}'; exec '${LAUNCHER_ANKI}' --base '${ANKI_BASE}' --profile '${PROFILE}'"
fi
(
    run_as_anki "${START_CMD}"
) > >(sed 's/^/[anki] /' | tee -a "${ANKI_LOG}") \
  2> >(sed 's/^/[anki][stderr] /' | tee -a "${ANKI_LOG}" >&2) &
ANKI_PID=$!

# ── 4. Wait for AnkiConnect ────────────────────────────────────────────────────
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

# ── 5. Trap and forward signals ────────────────────────────────────────────────
_shutdown() {
    echo "[entrypoint] shutting down"
    kill "${ANKI_PID}" 2>/dev/null || true
    kill "${XVFB_PID}" 2>/dev/null || true
}
trap _shutdown SIGTERM SIGINT

wait "${ANKI_PID}"
