# 202 — Say something

## Current behavior

The machine can think and cannot be heard. Everything that goes wrong before this
ticket is diagnosed by watching a computer sit still.

## Intended behavior

Output, on the simplest device that exists, working before anything else needs
debugging.

## Suggested implementation steps

1. Use the serial port. Write one byte to one address and it appears on a wire.
   It needs no description, no driver in any real sense, and it works before
   display, before storage, and before anything requiring knowledge of a specific
   part. This is how a machine that has just woken says anything at all
   (`docs/003`).
2. Expose it as a tool call, so the model can talk rather than only the engine.
3. Make the engine use it too, for its own progress — memory found, weights
   located, first token produced. The machine should be narrating its own startup
   before it is capable of being asked to.
4. Handle the case where there is no serial port on the board. Say so at build
   time rather than discovering it in the field, and name the fallback device
   explicitly; a machine that cannot speak is a machine nobody can help.
5. Keep it write-only and unbuffered. Buffering output is an optimisation that
   loses exactly the last thing said, which is exactly the thing worth reading
   after a crash.

## Blocks

Practically everything. Every later ticket is debugged through this.

## Blocked by

`201`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the serial port as the first thing that
should exist.
