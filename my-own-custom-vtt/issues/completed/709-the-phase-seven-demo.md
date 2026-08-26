# 709 -- The phase seven demo

**Phase:** 7, the rules layer
**Blocked by:** every other issue in phase 7.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 6.

## Intended behaviour

**The same world, run under two rulesets, disagreeing.**

### What it shows

**The same command, permitted by one and refused by the other**, with the
sentence each gives. Not a contrived command — a move, made out of turn.

**The same thing, described differently.** `kind` 1 is a goblin with statistics
under A and an abstract token under B, and the server never learned which.

**The same viewer, told different amounts.** `may_know` returning everything under
A and nothing under B, shown as the fields that reach the wire.

**The same seed, rolling differently** — because the rulesets ask different
questions of the dice — and **the same seed rolling identically** when the same
ruleset runs twice.

**And the server unchanged between them.** State it, and if any file did change,
name it. That would be a finding rather than a footnote.

### The failure mode it should also show

A ruleset that raises an error. Show that the table keeps running, the command is
refused with a sentence saying the ruleset failed rather than that it declined,
and a repeatedly-failing hook is eventually stopped and reported once.

That is the whole argument for embedding Lua rather than compiling rules in, and
it is worth watching rather than describing.

### And the thing that does not work yet

**A rolled-back turn does not roll back the sheets.** The world's geometry returns
and the ruleset's numbers do not, because a Lua table is not a flat block of
bytes.

Show it. A rollback that restores positions and not hit points is a rollback that
looks like it worked, and hiding that in a demo would be the demo lying.

## Suggested implementation steps

1. Load ruleset A, run a scripted sequence, print what happened.
2. Load ruleset B, run the identical sequence, print what happened.
3. Print them side by side where it fits.
4. Provoke the error case deliberately.
5. Demonstrate the sheet rollback gap rather than avoiding it.
6. Confirm `./run-phase-demo 7`.
