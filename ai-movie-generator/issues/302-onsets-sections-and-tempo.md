# 302 — onsets sections and tempo

phase 3, the ear

**Depends on:** 301

## Current behavior

Only the envelope exists.

## Intended behavior

Onsets (jumps over the recent average, local peaks, with strength), sections (smoothed energy bands held for a minimum length, labelled silent/quiet/steady/driving/peak), and tempo (histogram of onset gaps; `false` when no clear peak). Written as `beat-sheet.lua`.

## Suggested implementation steps

1. Each measure as its own function.
2. Tests with generated clicks at a known tempo, and with noise (tempo must be false).

## Related documents

- docs/datapath-listening.md
- docs/beat-sheet-format.md
