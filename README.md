# ankiconnect-relay

A thin HTTP relay that exposes [AnkiConnect](https://ankiweb.net/shared/info/2055492159) to the network.

AnkiConnect only listens on `127.0.0.1:8765` inside the Anki Desktop container. This relay runs in the same network namespace and forwards all requests from external callers to AnkiConnect, returning responses verbatim.

The relay is fully API-compatible with AnkiConnect. Any existing AnkiConnect client only needs to change the target URL — no other modifications required.

## Architecture

```text
external caller
      ↓  POST /
ankiconnect-relay  (shared network namespace)
      ↓  POST 127.0.0.1:8765
AnkiConnect addon
      ↓
Anki Desktop
      ↓
TigerVNC / noVNC (virtual desktop)
```

## API

### AnkiConnect relay — `POST /`

Fully compatible with the AnkiConnect protocol. Send any standard AnkiConnect envelope:

```json
{
  "action": "<action>",
  "version": 6,
  "params": {}
}
```

**Examples**

Create a deck (supports hierarchy with `::`):
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

### Internal probes

These endpoints are relay-specific and do not conflict with any AnkiConnect action.

| Endpoint | Description |
|----------|-------------|
| `GET /_/health` | Liveness check — `{"ok": true}` |
| `GET /_/status` | Runtime state — Anki process, AnkiConnect availability, install state |

## Running

### 1. Build images

```bash
# Anki desktop container
cd docker/anki
docker build -t ankiconnect-relay-anki:latest .

# Relay
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
3. Install AnkiConnect add-on (code `2055492159`) via Tools → Add-ons → Get Add-ons, or visit https://ankiweb.net/shared/info/2055492159
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
| `ANKI_BASE` | `/anki-data` | Anki data directory (for `/_/status`) |
| `ANKI_PROGRAM_FILES_DIR` | `/home/anki/.local/share/AnkiProgramFiles` | Launcher install dir (for `/_/status`) |

## Tech stack

- **Go** + **Gin**
- **Anki Desktop** + **AnkiConnect** addon
- **TigerVNC** + **noVNC**
