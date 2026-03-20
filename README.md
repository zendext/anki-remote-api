# ankiconnect-relay

A thin HTTP relay that exposes [AnkiConnect](https://foosoft.net/projects/anki-connect/) to the network.

AnkiConnect only listens on `127.0.0.1:8765` inside the Anki Desktop container. This relay runs in the same network namespace and forwards requests from external callers to AnkiConnect, returning the response verbatim.

## Architecture

```text
external caller
      ↓  POST /anki
ankiconnect-relay  (shared network namespace)
      ↓  POST 127.0.0.1:8765
AnkiConnect addon
      ↓
Anki Desktop
      ↓
TigerVNC / noVNC (virtual desktop)
```

## API

### `GET /health`

Liveness check.

```json
{"ok": true}
```

### `GET /status`

Runtime state probe. Reports whether Anki is installed, running, and AnkiConnect is reachable.

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

### `POST /anki`

Relay endpoint. Forwards the request body to AnkiConnect and returns its response verbatim.

The caller constructs a standard AnkiConnect envelope:

```json
{
  "action": "<action>",
  "version": 6,
  "params": {}
}
```

**Examples**

Create a deck:
```json
{"action": "createDeck", "version": 6, "params": {"deck": "My Deck::Sub Deck"}}
```

Create a note type (model):
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

Add a note:
```json
{
  "action": "addNote",
  "version": 6,
  "params": {
    "note": {
      "deckName": "My Deck",
      "modelName": "vocab-basic",
      "fields": {"Front": "ephemeral", "Back": "adj. 短暂的"},
      "tags": []
    }
  }
}
```

Full AnkiConnect action reference: https://foosoft.net/projects/anki-connect/

## Running

### 1. Build images

```bash
# Anki desktop container
cd docker/anki
docker build -t ankiconnect-relay-anki:latest .

# Relay API
cd ../..
docker build -t ankiconnect-relay:latest .
```

### 2. Start Anki container

```bash
docker run -d \
  --name ankiconnect-relay-<user_id>-anki \
  --restart unless-stopped \
  -e ANKI_PROFILE="User 1" \
  -e KEEP_DESKTOP_ALIVE=1 \
  -e WAIT_FOR_ANKICONNECT=0 \
  -v /path/to/<user_id>/anki-data:/anki-data \
  -v /path/to/<user_id>/program-files:/home/anki/.local/share/AnkiProgramFiles \
  -v /path/to/<user_id>/uv-cache:/home/anki/.cache/uv \
  ankiconnect-relay-anki:latest
```

### 3. First-run manual setup (required once)

Open the noVNC desktop (`http://<host>:6080/vnc.html`) and complete:

1. Set display language in Anki preferences
2. Log in to AnkiWeb and sync
3. Install AnkiConnect add-on (code `2055492159`) via Tools → Add-ons → Get Add-ons
4. Restart the container — AnkiConnect activates after a full restart

### 4. Start relay container

The relay shares the Anki container's network namespace to reach `127.0.0.1:8765`:

```bash
docker run -d \
  --name ankiconnect-relay-<user_id> \
  --restart unless-stopped \
  --network container:ankiconnect-relay-<user_id>-anki \
  -e LISTEN_ADDR=:8080 \
  -e ANKICONNECT_URL=http://127.0.0.1:8765 \
  -e ANKI_BASE=/anki-data \
  -e ANKI_PROGRAM_FILES_DIR=/home/anki/.local/share/AnkiProgramFiles \
  -v /path/to/<user_id>/anki-data:/anki-data:ro \
  -v /path/to/<user_id>/program-files:/home/anki/.local/share/AnkiProgramFiles:ro \
  ankiconnect-relay:latest
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LISTEN_ADDR` | `:8080` | Relay listen address |
| `ANKICONNECT_URL` | `http://127.0.0.1:8765` | AnkiConnect endpoint |
| `ANKI_BASE` | `/anki-data` | Anki data directory (for /status) |
| `ANKI_PROGRAM_FILES_DIR` | `/home/anki/.local/share/AnkiProgramFiles` | Launcher install dir (for /status) |

## Tech stack

- **Go** + **Gin**
- **Anki Desktop** + **AnkiConnect** addon
- **TigerVNC** + **noVNC**
