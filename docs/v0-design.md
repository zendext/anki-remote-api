# anki-remote-api — v0 Design

## 1. Goals and scope

### Goals

Build a v0 remote card creation system for Anki that supports:

- Receiving structured flashcard data from external callers (Discord skill, CLI, etc.)
- Routing per user to the correct Anki container
- Writing cards via `API service → AnkiConnect → Anki Desktop`
- Managing decks, business templates, and note lifecycle (lookup / create / update / upsert)

### In scope for v0

- One container = one Anki user
- Multi-user supported by running multiple containers
- Discord skill maintains `discord_user_id → anki_user/container` binding in a shared DB
- Uses AnkiConnect addon — no custom addon
- Media: accept external URLs only; no TTS generation
- Business template/schema managed by this service, not by AnkiConnect

### Out of scope for v0

- Single-instance multi-tenancy
- Custom Anki addon development
- Complex template migration
- Auto-scaling or orchestration
- Advanced permission system
- TTS generation

---

## 2. Architecture

```
Discord skill (or any HTTP caller)
        ↓
  Binding DB / Registry
        ↓
  anki-remote-api (per-user container)
        ↓
   AnkiConnect
        ↓
  Anki Desktop
```

### Component responsibilities

| Component | Responsibilities |
|-----------|-----------------|
| Discord skill | Resolve `discord_user_id` → look up binding → build card payload → call `/v0/notes/upsert` |
| Binding DB | Store `discord_user_id → service_base_url + token + status` |
| anki-remote-api | Deck API, template API, lookup/upsert, dedup, merge rules, call AnkiConnect |
| AnkiConnect | Deck list/create, note create/find/update, model/field queries |
| Anki Desktop | Hold the user's isolated collection; final card storage |

---

## 3. Container design

Each user runs one container. Minimum contents:

1. **Anki Desktop** — isolated profile + data directory mount
2. **AnkiConnect addon** — exposes local HTTP to the API service
3. **anki-remote-api** — the service in this repo
4. **Local storage** — template registry (SQLite or PostgreSQL), service config

### Isolation per container

- Anki collection / profile
- Media directory
- Config files
- API token
- Deck / model state

---

## 4. Data models

### 4.1 Binding DB

Table: `anki_user_bindings`

| Column | Type | Notes |
|--------|------|-------|
| `discord_user_id` | string, unique | Discord user ID |
| `anki_user_id` | string | Internal Anki user identifier |
| `service_base_url` | string | URL of this service instance |
| `service_token` | string | Bearer token |
| `status` | string | `active \| disabled \| pending` |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

Optional extensions: `default_template_id`, `default_deck`, `notes`.

### 4.2 Business template

Managed by this service; not tied to the AnkiConnect model layer.

Fields:

| Field | Description |
|-------|-------------|
| `id` | Template identifier (e.g. `vocab-basic`) |
| `version` | Schema version |
| `name` | Display name |
| `description` | |
| `defaults.deck` | Default deck name |
| `defaults.tags` | Default tags |
| `dedupe.by` | Dedup key — always `canonical_term` for v0 |
| `schema` | JSON Schema for the note payload |
| `mapping.anki_model` | Target Anki model name |
| `mapping.field_map` | Payload field → Anki field mapping |
| `render_rules` | How to render `meanings` / `examples` to HTML |

### 4.3 Note payload — vocab-basic (v0 primary template)

```json
{
  "term": "abate",
  "term_type": "word",
  "phonetic": "/əˈbeɪt/",
  "meanings": [
    {
      "pos": "verb",
      "gloss_zh": "减轻；减弱",
      "gloss_en": "to become less strong"
    }
  ],
  "examples": [
    {
      "text": "The storm suddenly abated.",
      "translation": "The storm suddenly weakened."
    }
  ],
  "audio_url": "https://example.com/abate.mp3",
  "tags": ["discord", "vocab"],
  "source": {
    "app": "discord",
    "channel_id": "1480800595735482411"
  }
}
```

### 4.4 canonical_term normalization

Rules applied in order:

1. Trim leading/trailing whitespace
2. Lowercase
3. Collapse internal whitespace to single space

Examples: `Abate`, ` abate `, `ABATE` → `abate`

---

## 5. API design

### 5.1 Health

```
GET /health
```

Returns status of: service, AnkiConnect, Anki Desktop.

```json
{
  "service": "ok",
  "ankiconnect": "ok",
  "anki": "ok"
}
```

---

### 5.2 Deck API

```
GET  /v0/decks
POST /v0/decks
POST /v0/decks/ensure
```

#### POST /v0/decks/ensure

Request:
```json
{ "name": "English::Words" }
```

Response:
```json
{
  "exists": true,
  "created": false,
  "deck": { "name": "English::Words" }
}
```

---

### 5.3 Template API

```
GET   /v0/templates
GET   /v0/templates/{template_id}
POST  /v0/templates
PATCH /v0/templates/{template_id}
POST  /v0/templates/{template_id}/render-preview  (optional)
```

---

### 5.4 Note API

#### POST /v0/notes/lookup

Dedup check by `template_id + deck + canonical_term`.

Request:
```json
{
  "template_id": "vocab-basic",
  "deck": "English::Words",
  "term": "abate"
}
```

Response:
```json
{
  "found": true,
  "note_id": "1712345678901",
  "fields": { "term": "abate" }
}
```

#### POST /v0/notes

Create a new note.

#### PATCH /v0/notes/{note_id}

Update a note. Supports two modes: `replace` and `merge`.

#### POST /v0/notes/upsert

Primary endpoint for external callers.

Request:
```json
{
  "template_id": "vocab-basic",
  "deck": "English::Words",
  "update_mode": "merge",
  "note": { ... }
}
```

Response (created):
```json
{ "action": "created", "note_id": "1712345678901" }
```

Response (updated):
```json
{
  "action": "updated",
  "note_id": "1712345678901",
  "updated_fields": ["meanings", "examples"]
}
```

---

## 6. Merge / update rules

| Field | Strategy | Rule |
|-------|----------|------|
| `meanings` | merge | Deduplicate by `pos + gloss_zh + gloss_en` |
| `examples` | merge | Deduplicate by `text + translation` |
| `tags` | merge | Set union |
| `audio_url` | replace | Always overwrite |
| `phonetic` | replace | Non-empty new value overwrites; empty new value is ignored |

---

## 7. AnkiConnect boundary

| Layer | Handles |
|-------|---------|
| AnkiConnect | Deck list/create, note create/find/update, tags, model/field queries |
| anki-remote-api | Business templates, dedup, canonical_term, merge rules, render rules, upsert semantics |

---

## 8. Skill call flow

1. Skill resolves `discord_user_id`
2. Skill queries Binding DB → gets `service_base_url` + `service_token`
3. Skill builds structured note payload
4. Skill calls `POST /v0/notes/upsert` on the target container
5. Service returns `created` or `updated`
6. Skill reports result to user

---

## 9. Tech stack

| Component | Choice | Reason |
|-----------|--------|--------|
| Language | Go | Single binary, clean container image, strong typing |
| HTTP framework | Gin | Lightweight, idiomatic |
| DB layer | `database/sql` with pluggable drivers | Driver selected from `DATABASE_URL` scheme |
| SQLite driver | `modernc.org/sqlite` | Pure Go, no CGO required |
| PostgreSQL driver | `pgx` | Production use |
| Storage | SQLite (open-source/local) or PostgreSQL (production) | |
| Internal comms | AnkiConnect via `net/http` | Standard library, no extra deps |

### DATABASE_URL scheme routing

| Scheme | Driver |
|--------|--------|
| `sqlite://` | `modernc.org/sqlite` |
| `postgres://` or `postgresql://` | `pgx` |

SQL is written to be compatible with both dialects. PG-specific features (e.g. JSON operators) are avoided in the core query paths.

---

## 10. Security

- AnkiConnect is **not** exposed outside the container
- External callers only reach the API service
- Each container has an independent Bearer token
- API service listens on a controlled network interface only

---

## 11. Phased implementation plan

### Phase 1 — Core execution path
- Single-user container with Anki + AnkiConnect running
- API service: `/health`, deck list/create, note create/find/update

### Phase 2 — Business template layer
- Define `vocab-basic` template
- Template CRUD
- Render rules
- `canonical_term` normalization

### Phase 3 — Upsert
- `lookup` implementation
- Merge / update rules
- `POST /v0/notes/upsert`

### Phase 4 — Discord skill integration
- Binding DB schema and query interface
- Skill routing by `discord_user_id`
- Return created/updated result to user

### Phase 5 — Multi-user prep
- Standardize container image and env vars
- Support multiple instances

---

## 12. Recommended build order

1. Single-user container + API service + AnkiConnect connectivity
2. Lock down `vocab-basic` template
3. Implement `/v0/notes/upsert`
4. Wire up Discord skill + Binding DB
