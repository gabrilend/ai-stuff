# 402 — Manifests and twinned-file sync

phase 4, placement

## Current behavior

Nothing exists.

## Intended behavior

- **Manifest**: for every twinned file, one line `sha256 size path`, sorted
  by path. Hashing is split across one worker per CPU core; the list of
  files is made first and each worker takes a share of it.
- **Sync** as a courier step: build or refresh the near manifest, fetch the
  distant one, compare by **owning side** (401):
  - near-owned and different or missing on distant: copy near → distant
    (no approval needed: the distant computer is the steward's);
  - distant-owned and different or missing on near: write a request of a
    new kind, `twin` (body: path, size, checksum), whose applier copies the
    file in over the link;
  - a copy changed by the side that does not own it: an error naming the
    file and both checksums. It is never merged or overwritten, because it
    means some program broke the pledge (`docs/datapath-link.md`,
    "Crystallized: the other side's parts").
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
