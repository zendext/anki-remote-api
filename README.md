# ankiconnect-relay

A thin HTTP relay that exposes [AnkiConnect](https://ankiweb.net/shared/info/2055492159) from a containerized Anki Desktop runtime.

This repository now has two separate concerns:

- `docker/anki`: a containerized Anki Desktop runtime with noVNC access
- `ankiconnect-relay`: an optional companion relay for exposing AnkiConnect after you install it manually inside Anki

AnkiConnect usually listens on `127.0.0.1:8765` inside the Anki container, so external clients cannot reach it directly. `ankiconnect-relay` runs in the same network namespace, forwards requests to the local AnkiConnect endpoint, and returns responses unchanged.

## Highlights

- AnkiConnect-compatible relay at `POST /`
- No client changes beyond replacing the base URL
- Health and status probes for automation
- Dockerized Anki Desktop runtime with TigerVNC and noVNC

## How it works

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

The relay must share the Anki container network namespace:

- Docker Compose: `network_mode: service:anki`
- Docker CLI: `--network container:<anki-container>`

## API

### `POST /`

Send a standard AnkiConnect envelope:

```json
{
  "action": "<action>",
  "version": 6,
  "params": {}
}
```

This project does not duplicate the full AnkiConnect API docs. See the add-on page:

- https://ankiweb.net/shared/info/2055492159

Minimal connectivity check:

```bash
curl -s http://localhost:8080/ \
  -H 'Content-Type: application/json' \
  -d '{"action":"version","version":6}'
```

### Probe endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /_/health` | Liveness check |
| `GET /_/status` | Runtime and bootstrap state |

Example health response:

```json
{"ok": true}
```

## Quick start

### Docker Compose

1. Prepare data directories and ensure they are writable by `1000:1000`:

```bash
mkdir -p ./.data/anki-data ./.data/program-files ./.data/uv-cache
chown -R 1000:1000 ./.data
```

2. Create the env file:

```bash
cp docker/.env.example docker/.env
```

3. Build the Anki desktop image:

```bash
docker build -t ankiconnect-relay-anki:latest ./docker/anki
```

4. Start the stack:

```bash
cd docker
docker compose build
docker compose up -d
```

5. Open noVNC:

```text
http://<host>:6080/vnc.html
```

6. Verify the relay:

```bash
curl -s http://<host>:8080/_/health
curl -s http://<host>:8080/_/status
curl -s http://<host>:8080/ \
  -H 'Content-Type: application/json' \
  -d '{"action":"version","version":6}'
```

## First run

On first launch, open the noVNC desktop and complete the one-time Anki setup:

1. Choose language and confirm the expected profile
2. Log in to AnkiWeb and sync if needed
3. Install or verify the AnkiConnect add-on
   - code: `2055492159`
   - URL: https://ankiweb.net/shared/info/2055492159
4. Restart the Anki container

If `version` succeeds afterward, the stack is ready.

## Configuration

### Relay env

| Variable | Default | Description |
| --- | --- | --- |
| `LISTEN_ADDR` | `:8080` | Relay listen address |
| `ANKICONNECT_URL` | `http://127.0.0.1:8765` | Target AnkiConnect endpoint |
| `ANKI_BASE` | `/anki-data` | Used by `/_/status` |
| `ANKI_PROGRAM_FILES_DIR` | `/home/anki/.local/share/AnkiProgramFiles` | Used by `/_/status` |

### Common Anki runtime env

| Variable | Default | Description |
| --- | --- | --- |
| `ANKI_PROFILE` | `User 1` | Anki profile name |
| `KEEP_DESKTOP_ALIVE` | `1` | Keep desktop alive after Anki exits |
| `WAIT_FOR_ANKICONNECT` | `0` | Wait for AnkiConnect on startup |
| `VNC_PORT` | `5901` | TigerVNC port |
| `NOVNC_PORT` | `6080` | noVNC port |
| `VNC_PASSWORD` | empty | Optional VNC password |

## Troubleshooting

### `/_/health` works but `POST /` fails

Usually AnkiConnect is not ready yet. Check `/_/status` for:

- `ankiconnect_ready: false`
- `manual_intervention_required: true`
- `runtime_state: bootstrap`

Common causes:

- first-run setup not completed
- AnkiConnect not installed
- Anki not restarted after add-on installation
- Anki crashed during startup

### Relay cannot reach AnkiConnect

Make sure the relay shares the Anki container network namespace. Otherwise `127.0.0.1:8765` points back to the relay container itself.

### Volume permissions are wrong

Pre-create host bind-mount directories and ensure ownership is `1000:1000`.

## Security

This project exposes AnkiConnect beyond localhost. Do not publish it to untrusted networks without your own access control.

At minimum:

- protect VNC/noVNC access
- set `VNC_PASSWORD` outside trusted environments
- put the relay behind your own auth/gateway layer if needed

## Tech stack

- Go
- Gin
- Anki Desktop
- AnkiConnect
- TigerVNC
- noVNC
