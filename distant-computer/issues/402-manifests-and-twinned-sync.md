# 402 — Manifests and twinned-file sync

phase 4, placement

## Current behavior

Nothing exists.

## Intended behavior

- **Manifest**: for every twinned file, one line `sha256 size path`, sorted
  by path. Hashing is split across one worker per CPU core; the list of
  files is made first and each worker takes a share of it.
- **Sync** as a courier step: build or refresh the near manifest, fetch the
  distant one, compare, then copy near → distant for what is newer or only
  on near (no approval needed: the distant computer is the steward's). For
  what is only on distant, write a request of a new kind, `twin` (body: path,
  size, checksum), whose applier copies the file in over the link. For a
  checksum mismatch where both changed, write a `decision`.
- A manifest is refreshed by size and modification time first; a file is
  only re-hashed if either changed.

## Suggested implementation steps

1. Manifest building with workers; a test that one worker and many give the
   same manifest.
2. The comparison as a pure function of two manifests, with tests per case.
3. The `twin` kind added to the request checks (201) and gate kinds (202).
4. The courier step.

## Related documents

- `docs/datapath-placement.md`

## Blocked by

301, 302, 401.

## Blocks

404.
