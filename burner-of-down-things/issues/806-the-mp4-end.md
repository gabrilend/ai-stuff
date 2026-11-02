# 806 — The .mp4 end

Motion: the `.png` painter frame by frame; frames to `ffmpeg` for `.mp4`, and the same frames to the house GIF encoder for `.gif` ([067](../docs/067-datapath-the-studio.md), *decisions*).

## Current Behavior

Step 1 is built: `src/155-the-motion.lua` reads a `.mp4` canvas (the
`.png` words plus `frames`, `rate` and `move`) through the wall and works
out each frame from its number alone. Checked by
`tests/156-checking-frames-and-moves.lua`. Steps 2 and 3 need the
painter (803, raylib) to paint frames, so there are still only stills.

## Intended Behavior

- Canvas words `frames`, `rate`, and `move{ word = …, field = …, from = …, to = … }`; every moment worked out from the frame number, never the clock.
- Frames painted across worker processes, gathered in frame order; the result is the same with one worker or many.
- `.mp4` by `ffmpeg`, which is a borrowed encoder — the owner confirms this (docs/010); `.gif` by the house encoder (gif-generator's), so one path has no borrowed bytes.

## Suggested Implementation Steps

1. Frames and moves. **Test:** frame N of a move is where the arithmetic says. Done.
2. Parallel painting. **Test:** one worker and four give identical frames.
3. Both encoders. **Test:** `ffprobe` reports the frame count and rate; the `.gif` round-trips through the house decoder.

## Decisions

- Step 1 is built ahead of 804: working out where things are on frame N
  needs the wall (802), not the `.png` end. Painting (step 2) and
  encoding (step 3) wait on the painter.
- `frames{ count }` is required once (frames numbered from 0); `rate{
  per_second }` is optional, default 30.
- A move names a surface (the only named thing) and moves its `colour` or
  an `offset` added to all its corners; `from`/`to` must fit the field.
  `start` defaults to 0 and `stop` to the last frame; a move whose start
  is its stop jumps. Easing is linear only, for now.
- Colours round to whole channels on each frame; offsets stay exact (the
  painter rounds pixels).
- An arrow whose end is a moving surface moves that end with it.
- A frame is a new table built from the still and the frame number; the
  still is never changed, so frames can be worked out in any order or on
  any worker (step 2's promise holds by construction).
- The `.mp4` paintbrush is the `.png` paintbrush's words plus these
  three, with its document generated as `docs/paintbrush-mp4.md`.

## Blocked by

- 804
