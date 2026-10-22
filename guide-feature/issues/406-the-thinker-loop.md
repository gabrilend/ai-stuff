# 406 — The thinker loop

phase 4, the thinkers

## Current behavior

The pieces exist separately (402–405). Stand-in voices (304) send scripted
frames.

## Intended behavior

The thinker as a running program: reads `input/thinker` (101), then repeats
the loop in `docs/datapath-thinker.md` (read the page, gather, build, ask
until it fits, write the frame) until stopped, then writes its goodbye
receipt.

The frame is written with the headers of `docs/frame-format.md`, checked by
reading it back with the frame reader (102) before it is renamed into the
outbox, so a thinker can never send a frame the page keeper would refuse for
its shape. The frame counter is kept in a small state file in the mailbox
folder (not in RAM), so a restart continues the count.

First run on kuvalu, as a replacement for one stand-in voice in the
rehearsal (304). Then all three.

## Suggested implementation steps

1. The loop and the state file.
2. Swap a stand-in voice for a thinker in the rehearsal and run it.
3. Goodbye counters as listed in `docs/datapath-thinker.md`.

## Related documents

- `docs/datapath-thinker.md`

## Blocked by

101, 102, 304, 405.

## Blocks

407, 504.
