# 204 — Run what it wrote

## Current behavior

**Done, and run on a real processor** — `src/073` is the assembler, `src/074`
places and calls, `src/075` proves both, 18 of 18 on 2026-08-02. A program
written the way the machine would write it is assembled, placed in real
executable memory, called, and gives the right answer; a loop that ends
ends; and a loop that would not end is caught.

**The assembler was chosen over raw bytes**, and the deciding argument was
step four rather than convenience: the assembler is ours, so it inserts the
emission at every loop back-edge instead of relying on the model to
remember. A model that has to remember will forget, and the first forgetting
ends the machine.

Positions are settled twice — once to find which jumps go backwards, then
again with the emissions in place — because inserting them afterwards would
move every label they sit before, which is how a watched program jumps into
the middle of its own watch.

Placing writes through the memory rules of `203` rather than around them, so
putting a program on top of the engine is refused by the same check that
refuses any other write there. The bytes and the text they came from are
kept together, with hands to ask what has been built and what a program was
made from.

**The defect worth carrying forward: a watch that changes what it watches is
not a watch.** The first emission saved the registers it borrowed and not
the flags — and a back-edge sits immediately after the comparison that
decides whether to take it. Adding one to a number sets the flags,
destroying the comparison the jump was about to read, so every loop turned
on the watchdog's arithmetic rather than its own. Every loop became endless,
including the correct ones, and the machine hung rather than failing. The
emission now saves the flags, and the rule is written where it will be
reread: everything the processor carries between instructions comes back
exactly as it was.

**What escapes, named rather than discovered.** Code that did not come
through this assembler carries no emissions, and so does a loop built from
something not recognised as a back-edge; the instruction budget is the slow
fallback for both, and it needs a machine that can single-step. And on a
host the *taking* of control cannot be shown at all — a hosted process
cannot be stopped from inside itself, so a runaway is noticed after it
finishes rather than interrupted. `601` is where the interruption is proven
rather than arranged.

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
