# Release

## Docker Hub image

```text
zendext/anki-novnc
```

## Image positioning

- containerized Anki Desktop runtime
- noVNC remote access
- AnkiConnect is not preinstalled

## GitHub Actions workflow

Workflow file:

```text
.github/workflows/release-anki-novnc.yml
```

The workflow publishes Docker Hub images from Git tags.

## Required GitHub repository secrets

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Tag format

```text
anki-<anki_version>-build<build_number>
```

Example:

```text
anki-25.09.2-build1
```

## Published image tags

For a release tag like:

```text
anki-25.09.2-build1
```

The workflow publishes:

```text
zendext/anki-novnc:25.09.2-build1
zendext/anki-novnc:25.09.2
zendext/anki-novnc:25.09
```

## Create a release

```bash
git tag anki-25.09.2-build1
git push origin anki-25.09.2-build1
```
