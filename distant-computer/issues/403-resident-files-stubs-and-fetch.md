# 403 — Resident files: stubs and fetch

phase 4, placement

## Current behavior

Nothing exists.

## Intended behavior

- **Stubs**: for each resident file, the side without it holds a stub at its
  path (`docs/datapath-placement.md`, "Resident files and stubs"). Stubs are
  written by a courier step from the owning side's resident manifest.
- **fetch <path>**: on near, asks the transport for the file; on distant,
  writes a `fetch` request into the outbox and waits for the courier to
  carry the file into `answers/` (bounded by a time in `input/fetch`). The
  file lands in `tmp/shared-memory/fetched/`, checked against the stub's
  checksum.
- When the link is down (cut switch, failed transport, or `waiting` state),
  fetch fails at once with: which computer holds the file, and how long
  since the link was last up. It never returns an empty file.

## Suggested implementation steps

1. Stub format, write and read.
2. Fetch on near; then on distant through the outbox.
3. Tests: fetch works; fetch with the link cut fails with the message; a
   fetched file with a wrong checksum is an error.

## Related documents

- `docs/datapath-placement.md`

## Blocked by

301, 302, 401.

## Blocks

404.
