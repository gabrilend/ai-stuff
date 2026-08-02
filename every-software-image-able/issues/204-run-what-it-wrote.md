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
4. **Survive it not returning, using the status emission.** Code written by a
   model will sometimes loop forever, and without a way to regain control the
   first bad function ends the machine.

   The assembler is ours, so **it inserts a status emission at every loop
   back-edge** rather than relying on the model to remember. Any loop therefore
   reports, repetition pushes the magnitude away from fifty, and crossing a
   threshold is where control gets taken (`docs/006`). This is the same trick the
   grown machine's interpreter uses in its fetch loop, one layer further down, and
   it costs a few instructions per iteration rather than a timer, an interrupt
   table and a handler.

   Two holes worth naming rather than discovering. Code that did not come through
   our assembler — raw bytes, or a jump into the middle of something — escapes the
   emission. And a loop with no back-edge our assembler recognises escapes it too.
   For those, single-stepping with an instruction budget is the slow fallback that
   cannot be escaped, and it is worth having even if it is rarely reached.
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
