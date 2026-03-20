# anki-remote-api

A lightweight HTTP API service for remote Anki card creation and management.

This project sits between an HTTP caller and a per-user Anki Desktop runtime. The current validated runtime direction is a **non-root Anki Desktop container** with a **virtual desktop** exposed over **VNC/noVNC**.

## Current runtime direction

The current container strategy is:

- **Anki Desktop** running inside Docker
- **non-root user** (`uid=1000`, `gid=1000`)
- **TigerVNC + openbox + noVNC** for a virtual desktop
- persistent host mounts for:
  - Anki data directory
  - launcher-installed program files / virtualenv
  - uv cache

This keeps the runtime independent from the host desktop session while still allowing first-run debugging and manual setup through a browser.

## What it does

Planned service responsibilities:

- Accept structured flashcard payloads over HTTP
- Deduplicate by `canonical_term` before writing
- Create or merge-update notes via AnkiConnect
- Manage deck and business template configuration

## Architecture

```text
HTTP client
     ↓
anki-remote-api  ← this project
     ↓
AnkiConnect
     ↓
Anki Desktop
```

Each user gets an isolated Anki runtime with its own profile, media directory, launcher state, and API token.

## Tech stack

- **Go** — planned service implementation
- **Gin** — planned HTTP framework
- **database/sql** — planned DB layer with pluggable drivers
  - SQLite (`modernc.org/sqlite`, no CGO)
  - PostgreSQL (`pgx`)
- **Anki Desktop** — actual note runtime
- **AnkiConnect** — addon used by the API layer

## Current status

### Runtime

The Desktop container route is now validated far enough to confirm:

- non-root container runtime works better than root
- host X11 is **not required**
- virtual desktop in-container is viable
- first-run launcher state can be persisted and reused
- Anki Desktop window can be brought up through noVNC

### Still in progress

- make first-run bootstrap and later steady-state startup cleaner
- re-enable and validate AnkiConnect in the stabilized runtime path
- implement the Go HTTP API service itself

## Runtime model

The container now uses a single runtime model:

- always starts VNC/noVNC and the virtual desktop
- starts launcher when the installed Anki runtime is not present yet
- otherwise starts the installed Anki directly
- keeps the desktop alive even if the current Anki process exits, so manual GUI intervention remains possible

This avoids splitting the GUI lifecycle into separate operational modes. The container is always started the same way, while higher-level orchestration can decide whether the runtime is ready for service.

## Runtime mounts

Use persistent bind mounts for these container paths:

- `/anki-data`
- `/home/anki/.local/share/AnkiProgramFiles`
- `/home/anki/.cache/uv`

### Important

When using the non-root container, **do not rely on Docker to auto-create host bind-mount directories**.

Create them yourself first and set ownership to `1000:1000`, otherwise Docker will usually create them as `root:root`, which causes permission problems.

Example:

```bash
mkdir -p /path/to/anki-data
mkdir -p /path/to/program-files
mkdir -p /path/to/uv-cache
chown -R 1000:1000 /path/to/anki-data /path/to/program-files /path/to/uv-cache
```

## Minimal bridge API

A minimal Go bridge skeleton is now included.

Current endpoints:

- `GET /health`
- `GET /status`
- `POST /anki/version`
- `POST /anki/deck-names`

Environment variables used by the bridge:

- `LISTEN_ADDR` (default `:8080`)
- `ANKICONNECT_URL` (default `http://127.0.0.1:8765`)
- `ANKI_BASE` (default `/anki-data`)
- `ANKI_PROGRAM_FILES_DIR` (default `/home/anki/.local/share/AnkiProgramFiles`)

The current `/status` response is intentionally simple and is meant to be the first bridge-side runtime probe.

## Documentation

- [v0 Design](docs/v0-design.md)
- [TODO](docs/todo.md)
