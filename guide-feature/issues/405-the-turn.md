# 405 — The turn

phase 4, the turn

## Current behavior

The turn runner (304) runs a stand-in turn. The real pieces exist
separately (401–404).

## Intended behavior

The real turn, selected in `input/turn` in place of the stand-in: the seven
steps of `docs/datapath-voice-turn.md`. It reads the canvas, makes sure the
project clone matches (a no-op until 501), reads the endpoints, builds the
prompt, asks until it fits, and writes `outbox/canvas` with `base:` set to
the version it read. Before writing, the canvas is read back with the canvas
reader, so a voice can never send a canvas the blitter would refuse for its
form. The turn counter is kept on disk beside the mailbox.

First run in the rehearsal (305) on kuvalu, one voice, then all three.

## Suggested implementation steps

1. The turn, plugged into the runner through `input/turn`.
2. Run in the rehearsal and read every goodbye receipt.

## Related documents

- `docs/datapath-voice-turn.md`

## Blocked by

101, 102, 304, 305, 404.

## Blocks

406, 503, 704.
