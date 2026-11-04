# Phase 1 Progress — the record and the settings

## Goals
Every program reads its settings from input/ and refuses anything wrong,
writes a receipt on a clean exit, and can append to and check an append-only
ledger whose entries are chained by checksum, so an edit to the past shows.

Counts: `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/distant-computer -m`

## Completed Issues
- **101 — settings and the receipt.** Every program can now read its
  settings from `input/` with no hidden defaults, and leave a receipt and a
  run log. The first of the phase's three goals is met; the ledger (102)
  and the demo (103) remain. Tests: `tests/run-tests`.
