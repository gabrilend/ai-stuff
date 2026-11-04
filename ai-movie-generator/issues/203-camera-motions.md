# 203 — camera motions

phase 2, shots into motion

**Depends on:** 202

## Current behavior

Keyframes cannot move.

## Intended behavior

still, push_in, pull_out and pan turn one keyframe into `<shot id>.mp4` of exactly the shot's length, with eased camera movement, via ffmpeg's zoom-and-pan filter. Chosen by a dispatch table on the motion name. Shots encode in parallel on a thread pool (effil).

## Suggested implementation steps

1. One filter-string builder per motion.
2. Length check on every produced clip (ffprobe).
3. Thread pool over shots.
4. Tests: each motion on a test picture gives the right frame count.

## Related documents

- docs/datapath-shot-to-clip.md
