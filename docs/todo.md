# anki-remote-api v0 — TODO

## A. Research / Foundations

- [x] Confirm minimal viable setup for running Anki + AnkiConnect inside a container
- [x] Verify AnkiWeb sync v11 hostKey login protocol (zstd + anki-sync header)
- [ ] Confirm AnkiConnect interfaces needed for note lookup and update

## B. API Service Skeleton

- [ ] Initialize Go module and project layout
- [ ] Implement `GET /health`
- [ ] Add AnkiConnect client wrapper
- [ ] Add config loading (`DATABASE_URL`, `ANKICONNECT_URL`, `API_TOKEN`, `LISTEN_ADDR`)
- [ ] Add Bearer token authentication middleware
- [ ] Wire up `database/sql` with scheme-based driver selection (sqlite / postgres)

## C. Deck API

- [ ] `GET /v0/decks`
- [ ] `POST /v0/decks`
- [ ] `POST /v0/decks/ensure`

## D. Template API

- [ ] Define template storage model
- [ ] Seed `vocab-basic` initial template
- [ ] `GET /v0/templates`
- [ ] `GET /v0/templates/{id}`
- [ ] `POST /v0/templates`
- [ ] `PATCH /v0/templates/{id}`
- [ ] (optional) `POST /v0/templates/{id}/render-preview`

## E. Note API

- [ ] Define note payload struct and validation
- [ ] Implement `canonical_term` normalization
- [ ] `POST /v0/notes/lookup`
- [ ] `POST /v0/notes`
- [ ] `PATCH /v0/notes/{note_id}`
- [ ] `POST /v0/notes/upsert`

## F. Merge Logic

- [ ] `meanings` dedup and merge
- [ ] `examples` dedup and merge
- [ ] `tags` set union
- [ ] `phonetic` / `audio_url` replace strategy
- [ ] Render `meanings` and `examples` to Anki HTML fields

## G. Containerization

- [ ] Design container directory structure
- [ ] Write Dockerfile and docker-compose example
- [ ] Mount isolated profile / media / config volumes
- [ ] Configure API service ↔ AnkiConnect networking
- [ ] Container startup health check

## H. Discord Skill Integration

- [ ] Design Binding DB schema (`anki_user_bindings`)
- [ ] Provide binding query interface or logic
- [ ] Route by `discord_user_id` in skill
- [ ] Skill calls `POST /v0/notes/upsert`
- [ ] Skill returns human-readable result

## I. Testing

- [ ] Deck create / list integration tests
- [ ] Note create integration test
- [ ] Note lookup / update integration test
- [ ] Upsert: `created` path test
- [ ] Upsert: `updated` path test
- [ ] Merge dedup test

---

## Priority

### P0
- Container up and running (Anki + AnkiConnect)
- Deck API
- Note create / find / update
- `vocab-basic` template
- Upsert endpoint

### P1
- Template CRUD
- Render preview
- Binding DB + skill integration

### P2
- Extended media strategy
- Multi-template support
- Automated container provisioning
