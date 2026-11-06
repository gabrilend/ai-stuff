# 901d — Reuse refusal

The fourth piece of 901.

## Current Behavior

Built. `src/117-tag-numbers.lua`'s `accept(project, record, parcel)`
reads the parcel's tag (901b): no tag is accepted as it is and records
nothing; a malformed tag is refused with 901b's finding; a number already
recorded is refused, naming its first use ("number 1 was first used in
case notes, ledger line 2 (draw a circle)"), whichever case the reuse
arrives at; a fresh number is appended once to the arriving case's ledger
as a `numbered` line (about the number, text the wish). Checked by
`tests/120-checking-reuse-refusal.lua`.

Decisions: a number higher than the next free one is refused too, naming
the next free number — 901c says numbers are given by the machine, never
chosen by whoever writes the tag, and this is where that is enforced.
Two runs on two different cases at the same moment could each record the
same fresh number (each holds only its own case's lock); the router that
calls `accept` (904) is the place to serialise that when it is built.

## Intended Behavior

A parcel whose tag reuses a recorded number is refused, naming the first
use (case, ledger line); each new number is recorded in the ledger
exactly once.

## Suggested Implementation Steps

1. The reuse check against 901c's reader. 2. The ledger line recording a
   number's first use. **Test:** a reused number is refused, naming its
   first use; a fresh number is recorded once and accepted. Done: `117-tag-numbers.lua`'s `accept`.

## Blocked by

- 901c
