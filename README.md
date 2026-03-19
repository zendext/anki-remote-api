# anki-remote-api

A lightweight HTTP API service for remote Anki card creation and management.

Designed to sit between external callers (e.g. Discord bots, CLI tools) and a per-user Anki Desktop instance, handling deduplication, upsert logic, and template management on top of AnkiConnect.

## What it does

- Accepts structured flashcard payloads over HTTP
- Deduplicates by `canonical_term` before writing
- Creates or merge-updates notes via AnkiConnect
- Manages deck and business template configuration

## Architecture

```
Discord skill (or any HTTP caller)
        ↓
  Binding DB / Registry
        ↓
  anki-remote-api  ← this project
        ↓
   AnkiConnect
        ↓
  Anki Desktop
```

Each user gets an isolated container with its own Anki profile, media directory, and API token.

## Tech stack

- **Go** — single binary, clean container image
- **Gin** — HTTP framework
- **database/sql** — DB layer with pluggable drivers
  - SQLite (`modernc.org/sqlite`, no CGO) — for local / open-source use
  - PostgreSQL (`pgx`) — for production
- **AnkiConnect** — Anki addon, handles low-level note/deck operations

## Configuration

| Env var | Description | Example |
|---------|-------------|---------|
| `DATABASE_URL` | DB connection string | `postgres://user:pass@host/db` or `sqlite:///data/anki.db` |
| `ANKICONNECT_URL` | AnkiConnect endpoint | `http://localhost:8765` |
| `API_TOKEN` | Bearer token for this service | `your-secret-token` |
| `LISTEN_ADDR` | HTTP listen address | `:8080` |

The DB driver is selected automatically from the `DATABASE_URL` scheme.

## Documentation

- [v0 Design](docs/v0-design.md)
- [TODO](docs/todo.md)

## Status

> Phase 1 in progress
