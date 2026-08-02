# 204 — Run what it wrote

## Current behavior

The model can produce assembly as text. Nothing turns it into instructions and
nothing runs it.

## Intended behavior

The machine can execute code it has just written. **This is the hand that makes
the whole project possible** — the allocator, the interpreter, every driver and
every program the machine ever has are downstream of this one call.

## Suggested implementation steps

1. Decide whether the seed carries an assembler or whether the model emits
   machine code directly. An assembler is more software on the chip and makes
   everything after it far easier to write and to read back. Direct emission is
   less to build and asks the model to be exact about instruction encoding, which
   is where it is least reliable. The first is recommended.
2. Place the produced code somewhere known, in memory marked usable and not
   overlapping anything from `102`, and hand back the address it was placed at.
3. Call it, with arguments, and return what it returned. Define the convention
   once and write it into the bundled patterns (`303`), so that everything the
   machine writes afterward agrees with everything else it wrote.
4. **Survive it not returning.** Code written by a model will sometimes loop
   forever or jump somewhere meaningless. Without a way to regain control the
   first bad function ends the machine. Whatever mechanism the board offers —
   a timer that interrupts, a watchdog that resets — has to be in place before
   this call is offered, or the machine can only be given one chance.
5. Keep what was produced, alongside the text it came from. The pair is what
   makes a later reading of "why is this here" possible, and it is the first
   thing the machine builds that outlives the thought that made it.
6. Test with something small and verifiable end to end — a function that adds two
   numbers — before anything depends on it.

## Notes on effort

Step 4 is a ticket's worth of work by itself on some boards and should become
`204a` if it grows.

## Blocks

Everything the machine builds. Phase 6 cannot be attempted without it.

## Blocked by

`203`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the allocator in assembly is the first
thing this hand is used for.
