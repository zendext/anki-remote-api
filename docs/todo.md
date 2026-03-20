# anki-remote-api v0 — TODO

## A. Desktop runtime

- [x] Validate Anki Desktop in Docker
- [x] Switch to non-root desktop runtime
- [x] Validate in-container VNC/noVNC desktop
- [x] Persist launcher-installed Anki runtime
- [x] Verify manual AnkiConnect installation works
- [x] Remove VNC password requirement (insecure-public mode for development)
- [ ] Define stable container status signals for bridge consumption

## B. Bridge API skeleton

- [x] Initialize minimal bridge service layout
- [x] Implement `GET /health`
- [x] Add AnkiConnect client wrapper
- [x] Implement `GET /status`
- [x] Implement `POST /anki/version`
- [x] Implement `POST /anki/deck-names`
- [x] Validate bridge API reachable from within shared network namespace
- [ ] Add config validation and startup diagnostics
- [ ] Add Bearer token authentication middleware

## C. Bridge runtime state

- [ ] Distinguish launcher/bootstrap vs installed runtime more accurately
- [ ] Detect Anki process liveness separately from AnkiConnect availability
- [ ] Surface actionable `manual_intervention_required` semantics
- [ ] Include noVNC/VNC access hints in status when appropriate

## D. Bridge -> AnkiConnect API

- [ ] Add generic pass-through action endpoint or selected read-only probes
- [ ] `POST /v0/decks/ensure`
- [ ] `POST /v0/notes/lookup`
- [ ] `POST /v0/notes`
- [ ] `PATCH /v0/notes/{note_id}`
- [ ] `POST /v0/notes/upsert`

## E. Templates / business logic

- [ ] Define template storage model
- [ ] Seed `vocab-basic`
- [ ] Implement canonical term normalization
- [ ] Implement merge rules for meanings/examples/tags

## F. Packaging / docs

- [x] Update README to match current runtime model
- [x] Remove obsolete sync/hkey bootstrap docs from primary runtime path
- [x] Add API Dockerfile for bridge build
- [x] Document container launch commands and network topology
- [ ] Add API image self-test / smoke-test instructions

## Priority

### P0 — done
- Desktop runtime stable enough for repeated use ✓
- Bridge health / status / version / deckNames ✓
- AnkiConnect reachable from bridge container ✓

### P1 — next
- Bearer token auth middleware
- Deck ensure and note upsert flow
- Better runtime state reporting
