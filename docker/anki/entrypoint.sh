#!/usr/bin/env bash
set -euo pipefail

ANKI_BASE="${ANKI_BASE:-/anki-data}"
PROFILE="${ANKI_PROFILE:-User 1}"
PREFS_DB="${ANKI_BASE}/prefs21.db"
DISPLAY="${DISPLAY:-:99}"

# ── 1. Start Xvfb ──────────────────────────────────────────────────────────────
echo "[entrypoint] starting Xvfb on ${DISPLAY}"
Xvfb "${DISPLAY}" -screen 0 1024x768x24 -ac &
XVFB_PID=$!
sleep 1

# ── 2. Inject sync hkey ────────────────────────────────────────────────────────
if [[ -n "${ANKI_SYNC_HKEY:-}" ]]; then
    echo "[entrypoint] injecting sync hkey into prefs21.db"
    mkdir -p "${ANKI_BASE}"
    python3 /usr/local/bin/inject_hkey.py "${PREFS_DB}" "${PROFILE}" "${ANKI_SYNC_HKEY}"
else
    echo "[entrypoint] ANKI_SYNC_HKEY not set — skipping sync configuration"
fi

# ── 3. Start Anki ──────────────────────────────────────────────────────────────
echo "[entrypoint] starting Anki (profile: ${PROFILE})"
DISPLAY="${DISPLAY}" anki \
    --base "${ANKI_BASE}" \
    --profile "${PROFILE}" \
    2>&1 | sed 's/^/[anki] /' &
ANKI_PID=$!

# ── 4. Wait for AnkiConnect ────────────────────────────────────────────────────
echo "[entrypoint] waiting for AnkiConnect..."
ANKICONNECT_URL="${ANKICONNECT_URL:-http://localhost:8765}"
MAX_WAIT=60
WAITED=0
until curl -sf "${ANKICONNECT_URL}" -d '{"action":"version","version":6}' > /dev/null 2>&1; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo "[entrypoint] ERROR: AnkiConnect did not become ready within ${MAX_WAIT}s" >&2
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

# Keep container alive as long as Anki is running
wait "${ANKI_PID}"
