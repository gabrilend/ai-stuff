# 402 — Waking on the right foot

## Current behavior

Three engines exist on one chip and nothing chooses between them.

## Intended behavior

Power arrives, the processor is identified, the matching engine is selected, and
control is handed to it. This is the only code that runs before the machine can
think, and it is the smallest thing in the project.

## Suggested implementation steps

1. **The firmware picks, not us.** There is no code that runs on all three
   architectures, so nothing shared can identify a processor and dispatch to the
   matching engine — machine code is not portable and the detecting code would
   itself need an architecture. What actually happens is that each architecture's
   firmware looks in the place its own convention says to look, and finds only its
   own payload there. So this ticket is mostly about **image layout**: putting each
   engine where the firmware that would want it will go looking. Where that is
   comes from the board description (`501`).
2. Do the runtime detection that *is* possible, which is within an architecture
   rather than between them: which vector extensions this particular processor
   has. On x86-64 one set is guaranteed and better ones are common but not
   universal; on RISC-V the vector extension is optional entirely. Either target
   the guaranteed baseline everywhere, or carry more than one version of the hot
   loop and choose at startup — the second is faster and is three times the
   testing.
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
