# 503 — cutaways

phase 5, the monologue booth

**Depends on:** 502, 403

## Current behavior

The face is shown for the whole speech.

## Intended behavior

Cutaway shots laid over the face track at their times, speech continuing under them; the director finds cutaways in the text automatically.

## Suggested implementation steps

1. Overlay by ffmpeg.
2. Director instruction for finding seeable sentences.

## Related documents

- docs/datapath-monologue.md
