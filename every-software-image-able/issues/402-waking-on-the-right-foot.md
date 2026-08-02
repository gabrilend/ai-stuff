# 402 — Waking on the right foot

## Current behavior

Three engines exist on one chip and nothing chooses between them.

## Intended behavior

Power arrives, the processor is identified, the matching engine is selected, and
control is handed to it. This is the only code that runs before the machine can
think, and it is the smallest thing in the project.

## Suggested implementation steps

1. Identify the processor. Each architecture offers a way to ask what it is, and
   the awkwardness is that the asking is itself architecture-specific — so the
   entry point has to be reachable and meaningful on all three. How the firmware
   hands over differs per board and per boot scheme, and that difference belongs
   in the board description (`501`) rather than in this code.
2. Select and start. Nothing clever: a table from processor to entry point, which
   is the same dispatch shape the rest of the project uses.
3. Say what happened before handing over, on the serial port. "Found this
   processor, starting this engine" is the single most useful sentence a failing
   machine can produce, and at this moment it is the only thing that can be said
   at all.
4. Handle the unrecognised processor by saying so and stopping, rather than
   guessing. Starting the wrong engine executes nonsense as instructions, which is
   the least debuggable failure available.
5. Keep it out of the engines. This code is shared, tiny, and the one thing that
   cannot be got wrong quietly.

## Blocks

Phase 5 and phase 6.

## Blocked by

`401`.

## Related documents

`docs/010-datapath-the-mind.md` — the boot selecting whichever engine matches.
