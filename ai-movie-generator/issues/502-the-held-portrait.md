# 502 — the held portrait

phase 5, the monologue booth

**Depends on:** 501, 204, 301

## Current behavior

No monologue rendering.

## Intended behavior

One portrait keyframe of the speaker held for the whole speech: slow push-in, drift strength following the speech's loudness envelope. Output `<monologue id>.mp4` exactly as long as the speech.

## Suggested implementation steps

1. Portrait request (head-and-shoulders framing words).
2. Loudness-driven drift.
3. Length check.

## Related documents

- docs/datapath-monologue.md
