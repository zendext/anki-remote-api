# ankiconnect-relay

A thin HTTP relay that exposes [AnkiConnect](https://ankiweb.net/shared/info/2055492159) to the network.

`ankiconnect-relay` is designed for a containerized Anki Desktop runtime. Because AnkiConnect typically listens on `127.0.0.1:8765` inside the desktop container, external clients cannot reach it directly. This relay runs in the same network namespace, forwards requests to the local AnkiConnect endpoint, and returns responses verbatim.

The relay is intentionally minimal:

- **Protocol-compatible with AnkiConnect** at `POST /`
- **No client-side migration** other than changing the base URL
- **Container-friendly** deployment model
- **Built-in health and runtime probes** for automation and operations

## What problem this solves

AnkiConnect works well for local desktop automation, but it is not directly reachable when Anki Desktop is isolated inside a container or remote desktop environment.

This project bridges that gap:

- Anki Desktop runs in a virtual desktop container
- AnkiConnect stays bound to loopback inside that container namespace
- `ankiconnect-relay` exposes a regular HTTP endpoint for external callers
- Existing AnkiConnect clients can keep using the same request format

## Architecture

```text
external HTTP client
        ↓  POST /
ankiconnect-relay
        ↓  POST http://127.0.0.1:8765
AnkiConnect add-on
        ↓
Anki Desktop
        ↓
TigerVNC / noVNC virtual desktop
```

### Network model

The recommended deployment runs the relay in the **same network namespace** as the Anki container:

- Docker Compose: `network_mode: service:anki`
- Docker CLI: `--network container:<anki-container>`

This is the key design choice that lets the relay reach `127.0.0.1:8765` inside the Anki runtime.

## Repository layout

```text
.
├── cmd/server/                 # relay entrypoint
├── internal/app/               # HTTP server and probe handlers
├── internal/ankiconnect/       # thin AnkiConnect client used by the relay
├── docker/anki/                # Anki Desktop + VNC/noVNC container image
├── docker/docker-compose.yml   # local/dev single-user stack
├── Dockerfile                  # relay image
└── README.md
```

## Features

- **Full AnkiConnect request passthrough** via `POST /`
- **Health endpoint** for liveness checks
- **Status endpoint** for bootstrap / install-state visibility
- **Single-user Docker Compose example**
- **Containerized Anki Desktop runtime** with:
  - TigerVNC
  - noVNC
  - optional bundled AnkiConnect add-on

## API

### `POST /`

Fully compatible with the AnkiConnect protocol. Send any standard AnkiConnect envelope:

```json
{
  "action": "<action>",
  "version": 6,
  "params": {}
}
```

The relay forwards the raw request body to AnkiConnect and returns the raw response body unchanged.

### Example: create a deck

```json
{
  "action": "createDeck",
  "version": 6,
  "params": {
    "deck": "My Deck::Sub Deck"
  }
}
```

### Example: create a note type

```json
{
  "action": "createModel",
  "version": 6,
  "params": {
    "modelName": "vocab-basic",
    "inOrderFields": ["Front", "Back", "Phonetic", "Example"],
    "isCloze": false,
    "cardTemplates": [
      {
        "Name": "Card 1",
        "Front": "{{Front}}",
        "Back": "{{FrontSide}}<hr id=answer>{{Back}}"
      }
    ]
  }
}
```

### Example: add a note

```json
{
  "action": "addNote",
  "version": 6,
  "params": {
    "note": {
      "deckName": "My Deck",
      "modelName": "vocab-basic",
      "fields": {
        "Front": "ephemeral",
        "Back": "adj. short-lived"
      },
      "tags": []
    }
  }
}
```

### Example: query version with curl

```bash
curl -s http://localhost:8080/ \
  -H 'Content-Type: application/json' \
  -d '{"action":"version","version":6}'
```

For the full AnkiConnect action reference, see:

- https://foosoft.net/projects/anki-connect/
- https://ankiweb.net/shared/info/2055492159

### Internal probe endpoints

These routes are relay-specific and intentionally placed under `/_/` so they do not conflict with AnkiConnect actions.

| Endpoint | Purpose |
| --- | --- |
| `GET /_/health` | Liveness check |
| `GET /_/status` | Runtime and bootstrap state |

### `GET /_/health`

Example response:

```json
{"ok": true}
```

### `GET /_/status`

Example response:

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

Status fields are intended for operations and automation:

- `runtime_state`: bootstrap/install phase detection
- `ankiconnect_ready`: whether the relay can successfully call AnkiConnect
- `manual_intervention_required`: whether first-run/manual steps are still likely needed
- `program_files_ready`: whether the installed launcher/program files are present
- `anki_startup_log`: recent startup logs when available

## Quick start

### Option A: Docker Compose

This repository includes a single-user Compose stack in `docker/docker-compose.yml`.

### 1. Prepare directories

Create host directories in advance and make sure they are writable by UID/GID `1000:1000`.

Example:

```bash
mkdir -p ./.data/anki-data ./.data/program-files ./.data/uv-cache
chown -R 1000:1000 ./.data
```

### 2. Create `.env`

```bash
cp docker/.env.example docker/.env
```

Default variables:

```env
ANKI_DATA_DIR=./.data/anki-data
ANKI_PROGRAM_FILES_DIR=./.data/program-files
ANKI_UV_CACHE_DIR=./.data/uv-cache
VNC_PORT=5901
NOVNC_PORT=6080
LISTEN_PORT=8080
```

### 3. Build the Anki desktop image

The Compose file expects the Anki desktop image to already exist:

```bash
docker build -t ankiconnect-relay-anki:latest ./docker/anki
```

### 4. Build and start the Compose stack

From `docker/`:

```bash
cd docker
docker compose build
docker compose up -d
```

### 5. Open the desktop

Access noVNC in your browser:

```text
http://<host>:6080/vnc.html
```

### 6. Test the relay

```bash
curl -s http://<host>:8080/_/health
curl -s http://<host>:8080/_/status
curl -s http://<host>:8080/ \
  -H 'Content-Type: application/json' \
  -d '{"action":"version","version":6}'
```

## Option B: Docker CLI

### 1. Build images

```bash
# Build the Anki desktop image
cd docker/anki
docker build -t ankiconnect-relay-anki:latest .

# Build the relay image
cd ../..
docker build -t ankiconnect-relay:latest .
```

### 2. Start the Anki container

```bash
docker run -d \
  --name ankiconnect-relay-<user_id>-anki \
  --restart unless-stopped \
  -e ANKI_PROFILE="User 1" \
  -e KEEP_DESKTOP_ALIVE=1 \
  -e WAIT_FOR_ANKICONNECT=0 \
  -p 5901:5901 \
  -p 6080:6080 \
  -v /path/to/<user_id>/anki-data:/anki-data \
  -v /path/to/<user_id>/program-files:/home/anki/.local/share/AnkiProgramFiles \
  -v /path/to/<user_id>/uv-cache:/home/anki/.cache/uv \
  ankiconnect-relay-anki:latest
```

### 3. Complete first-run desktop setup

Open:

```text
http://<host>:6080/vnc.html
```

Then finish the one-time initialization steps described in the next section.

### 4. Start the relay container

The relay must share the Anki container's network namespace so it can reach `127.0.0.1:8765`.

```bash
docker run -d \
  --name ankiconnect-relay-<user_id> \
  --restart unless-stopped \
  --network container:ankiconnect-relay-<user_id>-anki \
  -p 8080:8080 \
  -e LISTEN_ADDR=:8080 \
  -e ANKICONNECT_URL=http://127.0.0.1:8765 \
  -e ANKI_BASE=/anki-data \
  -e ANKI_PROGRAM_FILES_DIR=/home/anki/.local/share/AnkiProgramFiles \
  -v /path/to/<user_id>/anki-data:/anki-data:ro \
  -v /path/to/<user_id>/program-files:/home/anki/.local/share/AnkiProgramFiles:ro \
  ankiconnect-relay:latest
```

## First-run bootstrap

The Anki desktop container is not fully ready for automation on the very first launch. A one-time manual setup is expected.

Open the noVNC desktop and complete the following:

1. Set your preferred UI language in Anki
2. Log in to AnkiWeb
3. Run the initial sync if needed
4. Verify the expected profile is being used
5. Install or verify the AnkiConnect add-on
   - Add-on code: `2055492159`
   - URL: https://ankiweb.net/shared/info/2055492159
6. Restart the Anki container after installation

After the restart, validate readiness with:

```bash
curl -s http://<host>:8080/_/status
curl -s http://<host>:8080/ \
  -H 'Content-Type: application/json' \
  -d '{"action":"version","version":6}'
```

If the relay returns a valid AnkiConnect version response, the stack is ready.

## Environment variables

### Relay container

| Variable | Default | Description |
| --- | --- | --- |
| `LISTEN_ADDR` | `:8080` | Relay listen address |
| `ANKICONNECT_URL` | `http://127.0.0.1:8765` | Target AnkiConnect endpoint |
| `ANKI_BASE` | `/anki-data` | Anki base directory used by `/_/status` |
| `ANKI_PROGRAM_FILES_DIR` | `/home/anki/.local/share/AnkiProgramFiles` | Program files directory used by `/_/status` |

### Anki desktop container

Common runtime variables used by `docker/anki/entrypoint.sh`:

| Variable | Default | Description |
| --- | --- | --- |
| `ANKI_PROFILE` | `User 1` | Anki profile name |
| `KEEP_DESKTOP_ALIVE` | `1` | Keep VNC desktop alive after Anki exits |
| `WAIT_FOR_ANKICONNECT` | `0` | Wait for AnkiConnect during startup |
| `VNC_PORT` | `5901` | TigerVNC port |
| `NOVNC_PORT` | `6080` | noVNC port |
| `VNC_GEOMETRY` | `1440x900` | Virtual desktop resolution |
| `VNC_DEPTH` | `24` | Virtual desktop color depth |
| `VNC_PASSWORD` | empty | Optional VNC password |

### Build-time proxy arguments

Both Dockerfiles accept build args for environments that require an outbound proxy:

- `HTTP_PROXY`
- `HTTPS_PROXY`
- `NO_PROXY`

Example:

```bash
docker build \
  --build-arg HTTP_PROXY=http://proxy.example:3128 \
  --build-arg HTTPS_PROXY=http://proxy.example:3128 \
  -t ankiconnect-relay:latest .
```

## Operational notes

- The relay is a **thin passthrough**, not a business-logic API.
- The relay assumes **AnkiConnect version 6-style envelopes**.
- The recommended topology is **one Anki runtime per user/profile context**.
- The relay depends on the Anki container being available because it forwards to `127.0.0.1:8765` inside the shared namespace.

## Troubleshooting

### `/_/health` is OK but `POST /` fails

Usually means the relay process is alive, but AnkiConnect is not ready.

Check:

```bash
curl -s http://<host>:8080/_/status
```

Look for:

- `ankiconnect_ready: false`
- `manual_intervention_required: true`
- `runtime_state: bootstrap`

Typical causes:

- first-run desktop setup not completed
- AnkiConnect add-on not installed yet
- Anki was not restarted after add-on installation
- Anki process crashed during startup

### noVNC works but AnkiConnect is still unavailable

This usually means the desktop is up, but the add-on or Anki process is not ready.

Recommended checks:

1. Confirm Anki is visibly running in the desktop
2. Confirm the add-on is installed
3. Restart the container once after add-on installation
4. Inspect `anki_startup_log` from `/_/status`

### Host bind mounts have wrong ownership

If Docker auto-created host directories as root, Anki may fail to initialize correctly.

Fix by pre-creating the directories and ensuring ownership is `1000:1000`.

### Relay cannot reach AnkiConnect

Make sure the relay shares the Anki container network namespace:

- Compose: `network_mode: service:anki`
- Docker CLI: `--network container:<anki-container>`

Without this, `127.0.0.1:8765` points to the relay container itself instead of the Anki runtime.

## Security notes

This project is meant to expose AnkiConnect beyond localhost, so you should treat it as a sensitive automation endpoint.

At minimum:

- do not expose it directly to untrusted networks without access control
- place it behind your own authentication / gateway layer if needed
- avoid publishing VNC/noVNC publicly without protection
- set `VNC_PASSWORD` if VNC access is enabled outside a trusted environment

This repository intentionally keeps the relay simple and does **not** implement its own auth layer.

## Tech stack

- **Go**
- **Gin**
- **Anki Desktop**
- **AnkiConnect**
- **TigerVNC**
- **noVNC**

## License

Add a license file if you plan to publish or distribute this project broadly.
