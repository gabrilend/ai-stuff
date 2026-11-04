# 301 — decoding and the threaded envelope

phase 3, the ear

**Depends on:** 101

## Current behavior

No sound is read.

## Intended behavior

ffmpeg decodes any input sound to mono 22050 Hz 16-bit raw in the run folder. The loudness envelope (RMS per 1/50 s window, normalised 0–1) is computed into an array allocated up front, the windows divided among threads (effil), each thread filling its own slice.

## Suggested implementation steps

1. Decode.
2. Allocate, split, measure in parallel.
3. Test: a generated tone with a silent gap gives the expected envelope shape.

## Related documents

- docs/datapath-listening.md
