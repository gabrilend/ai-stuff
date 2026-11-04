# 104 — the picture request and render log

phase 1, the image call and the run

**Depends on:** 102, 103

## Current behavior

Nothing paints.

## Intended behavior

`paint(request)` → a PNG path. The request fields and defaults are those in datapath-image-call.md (768×432, 20 steps, guidance 7, house negative with EasyNegative). Each call appends a line to the run's render log with seconds taken. A `run paint "<prompt>"` subcommand paints one picture for quick trials.

## Suggested implementation steps

1. Request validation (unknown field = error naming the known ones).
2. Fill, upload, queue, wait, fetch, write, log.
3. Test: same seed + prompt twice gives byte-identical PNGs (or record why not, if ComfyUI is non-deterministic on this card).

## Related documents

- docs/datapath-image-call.md
