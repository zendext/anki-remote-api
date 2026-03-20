# anki-remote-api

A lightweight HTTP API service for remote Anki card creation and management.

This project sits between an HTTP caller and a per-user Anki Desktop runtime. The validated runtime uses a **non-root Anki Desktop container** with a **virtual desktop exposed over VNC/noVNC** and a **bridge API container** sharing the same network namespace.

## Architecture

```text
HTTP client
     ↓
anki-remote-api (bridge API container)
     ↓  (localhost:8765, shared netns)
AnkiConnect addon
     ↓
Anki Desktop
     ↓
TigerVNC/noVNC (virtual desktop)
```

Each user gets an isolated stack:
- one `anki-vnc` container (Anki Desktop + AnkiConnect + noVNC)
- one `api` container sharing the `anki-vnc` network namespace

## Runtime model

The desktop container (`anki-remote-api-anki:latest-vnc`):

- Non-root user (`uid=1000`, `gid=1000`)
- TigerVNC + openbox + noVNC virtual desktop
- Single startup mode: launches launcher if Anki not installed, otherwise starts installed binary
- Desktop stays alive even if Anki exits (manual recovery via noVNC remains possible)
- VNC password optional; omit for insecure-public mode (development)

Persistent bind mounts:

| Host path | Container path | Purpose |
|-----------|---------------|---------|
| `.../anki-data` | `/anki-data` | Anki profiles, media, collections |
| `.../program-files` | `/home/anki/.local/share/AnkiProgramFiles` | launcher-installed Anki venv |
| `.../uv-cache` | `/home/anki/.cache/uv` | uv package cache |

## Running

### 1. Build images

```bash
# Anki desktop container
cd docker/anki
docker build \
  --build-arg HTTP_PROXY=http://192.168.50.1:23456 \
  --build-arg HTTPS_PROXY=http://192.168.50.1:23456 \
  -t anki-remote-api-anki:latest-vnc .

# Bridge API
cd ../..
docker build \
  --build-arg HTTP_PROXY=http://192.168.50.1:23456 \
  --build-arg HTTPS_PROXY=http://192.168.50.1:23456 \
  -t anki-remote-api-api:latest .
```

### 2. Start Anki container

```bash
docker run -d \
  --name anki-remote-api-<user_id>-anki-vnc \
  --restart unless-stopped \
  --network macvlan_net --ip 192.168.51.15 \
  -e ANKI_PROFILE="User 1" \
  -e KEEP_DESKTOP_ALIVE=1 \
  -e WAIT_FOR_ANKICONNECT=0 \
  -v /mediapool/docker-data/anki-remote-api/<user_id>/anki-data:/anki-data \
  -v /mediapool/docker-data/anki-remote-api/<user_id>/program-files:/home/anki/.local/share/AnkiProgramFiles \
  -v /mediapool/docker-data/anki-remote-api/<user_id>/uv-cache:/home/anki/.cache/uv \
  anki-remote-api-anki:latest-vnc
```

### 3. Start bridge API container

The API container shares the Anki container's network namespace so it can reach `127.0.0.1:8765`:

```bash
docker run -d \
  --name anki-remote-api-<user_id>-api \
  --restart unless-stopped \
  --network container:anki-remote-api-<user_id>-anki-vnc \
  -e LISTEN_ADDR=:8080 \
  -e ANKICONNECT_URL=http://127.0.0.1:8765 \
  -e ANKI_BASE=/anki-data \
  -e ANKI_PROGRAM_FILES_DIR=/home/anki/.local/share/AnkiProgramFiles \
  -v /mediapool/docker-data/anki-remote-api/<user_id>/anki-data:/anki-data:ro \
  -v /mediapool/docker-data/anki-remote-api/<user_id>/program-files:/home/anki/.local/share/AnkiProgramFiles:ro \
  anki-remote-api-api:latest
```

### Access

| Service | URL |
|---------|-----|
| noVNC (browser) | `http://<macvlan-ip>:6080/vnc.html` |
| Bridge API | `http://<macvlan-ip>:8080` |
| AnkiConnect (internal) | `http://127.0.0.1:8765` (localhost only) |

## API

### `GET /health`

```json
{"ok": true}
```

### `GET /status`

```json
{
  "desktop_up": true,
  "anki_process_running": true,
  "ankiconnect_ready": true,
  "runtime_state": "installed",
  "manual_intervention_required": false,
  "program_files_ready": true
}
```

### `POST /anki/version`

Returns AnkiConnect version.

### `POST /anki/deck-names`

Returns list of deck names from the active profile.

## Tech stack

- **Go** + **Gin** — bridge API
- **Anki Desktop** — actual note runtime
- **AnkiConnect** — addon bridging HTTP → Anki internals
- **TigerVNC + noVNC** — virtual desktop

## Current status

P0 goals are complete:

- Desktop runtime validated and stable
- Bridge API running, all implemented endpoints verified against live AnkiConnect
- AnkiConnect reachable from bridge container via shared network namespace

Next: Bearer token auth, deck ensure, note upsert.
