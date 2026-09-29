# 806 — The .mp4 end

Motion: the `.png` painter frame by frame; frames to `ffmpeg` for `.mp4`, and the same frames to the house GIF encoder for `.gif` ([067](../docs/067-datapath-the-studio.md), *decisions*).

## Current Behavior

Only stills.

## Intended Behavior

- Canvas words `frames`, `rate`, and `move{ word = …, field = …, from = …, to = … }`; every moment worked out from the frame number, never the clock.
- Frames painted across worker processes, gathered in frame order; the result is the same with one worker or many.
- `.mp4` by `ffmpeg`, which is a borrowed encoder — the owner confirms this (docs/010); `.gif` by the house encoder (gif-generator's), so one path has no borrowed bytes.

## Suggested Implementation Steps

1. Frames and moves. **Test:** frame N of a move is where the arithmetic says.
2. Parallel painting. **Test:** one worker and four give identical frames.
3. Both encoders. **Test:** `ffprobe` reports the frame count and rate; the `.gif` round-trips through the house decoder.

## Blocked by

- 804
