# 073, 074, 075 — running what it wrote — info

`073` is the seed's own assembler; `074` places what it produced, runs it,
and survives it not returning; `075` proves both on this processor with real
executable memory. Issue `204` — the hand the whole project rests on, since
the allocator, the interpreter, every driver and every program the machine
ever has are downstream of it.

## Running the checks

```
luajit src/075-test-run-what-it-wrote.lua
```

## Why an assembler rather than raw bytes

Both were on the table. Direct emission is less to build and asks the model
to be exact about instruction encoding, where it is least reliable. The
deciding argument is the escape: **the assembler is ours**, so it inserts the
status emission at every loop back-edge rather than relying on the model to
remember. A model that has to remember will forget, and the first forgetting
ends the machine.

## The back-edge is the whole trick

A jump backwards is a loop; there is no other way to make one out of jumps.
So every backward jump gets a few instructions before it that push the
machine-wide magnitude away from fifty, and crossing a threshold is where
control gets taken (`docs/006`). A handful of instructions per iteration
rather than a timer, an interrupt table and a handler — none of which exist
on a machine with nothing underneath it.

Positions are settled twice: once to find which jumps go backwards, then
again with the emissions in place. Inserting them afterwards would move every
label they sit before, which is how a watched program jumps into the middle
of its own watch.

## The defect worth carrying forward

**A watch that changes what it watches is not a watch.** The first emission
saved the registers it borrowed and not the flags — and a back-edge sits
immediately after the comparison that decides whether to take it. Adding one
to a number sets the flags, destroying the comparison the jump was about to
read, so every loop turned on the watchdog's arithmetic rather than its own.

Every loop became endless, including correct ones. The machine hung rather
than failing, which is this project's usual failure mode wearing new clothes.
The emission now saves the flags too, and the rule is stated where it can be
reread: registers, flags, and anything else the processor carries between
instructions come back exactly as they were.

## What is kept

The bytes and the text they came from, together, always — with hands to ask
what has been built (`built`) and what a program was made from (`why`). The
pair is what makes a later reading of "why is this here" possible, and it is
the first thing the machine builds that outlives the thought that made it.

## Placing goes through the memory rules

`place` writes byte by byte through `071`, so putting a program on top of the
engine is refused by the same check that refuses any other write there. A
hand that could bypass the one refusal would make the refusal decorative.

## The holes, named rather than discovered

Code that did not come through this assembler carries no emissions and
escapes the watch entirely. So does a loop built out of something the
assembler does not recognise as a back-edge. An instruction budget stepped
one at a time is the slow fallback for both, and it needs a machine that can
single-step.

And on a host, the *taking* of control cannot be shown: a hosted process
cannot be stopped from inside itself, so a runaway is noticed after it
finishes rather than interrupted mid-loop. The bound in the test is far past
the threshold for that reason. `601` is where the interruption is proven
rather than arranged.

## Result on 2026-08-02

18 of 18, with real instructions executing on this processor from memory the
machine placed them in.
