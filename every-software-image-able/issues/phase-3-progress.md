# Phase 3 — What it is told

**Goal.** The text payload the machine wakes up holding: the instruction, the
carried device descriptions, the bundled build patterns, and the decision about
which part of all that is present at the start versus fetched when relevant.

Settled while there is one engine to test against rather than three.

**The phase is complete, 2026-08-02**, in the only sense this phase can be:
the text exists, it says what it must and refrains from saying what it must
not, and all of it is reachable. Whether it *works* is `602`'s question.

## Issues

| | | Status |
|---|---|---|
| `301` | What the machine is told | **completed** — the order, the two prohibitions, what it is for; says the instruction can be rewritten and refuses to say what that costs |
| `302` | The descriptions it carries | **completed** — four classes, ten required sections each, and confirmation as a read-only act where a partial match is a failure |
| `303` | The patterns it carries | **completed** — eleven shapes, each saying where it stops working, each saying it is only a suggestion |
| `304` | What is said at once | **completed** — atoms, a small boot set, an index, fetching that costs visible room, and the disk half `105` left open; 43 of 43 across all four |

## Where the risk was

`301`, and the risk was never technical. Two things it had to do are in
tension: convey an order that cannot be rearranged and two prohibitions that
must not be softened, while not turning the four rungs, the status square and
the condensing into requirements.

Both halves are now checked rather than intended. The test searches the
instruction for the shapes that are only suggestions and requires their
absence — so a later well-meaning edit that explains the four rungs inside the
instruction fails a test rather than passing unnoticed.

The sharpest instruction in the ticket was step five: say the atoms can be
rewritten, do not say what it could cost. That is checked in both directions
too, because the natural instinct on rereading is to add a warning, and the
whole point is that the machine derives it.

## What is uncomfortable, and deliberate

The boot set is a mutable file, so the machine can change what it wakes up
believing — including dropping the prohibitions. Nothing prevents it. That
follows from everything about the machine being mutable, `docs/013` names it
as something nobody has decided is correct, and it is now tested so that
nobody builds on the assumption that it is untrue.

## The test of whether this phase succeeded

`602`, not anything here. Nothing in this phase can say whether a machine
given this text does the right thing with it — only leaving one alone and
watching says that, and a failure there is fixed in this text rather than at
the keyboard.

## Demo

The machine asked what it is carrying and answering, then asked for a pattern
it has not been shown and fetching it — both are hands, and both are
exercised in `085`. It joins the phase 2 demo rather than standing alone,
since a payload with no machine to read it demonstrates nothing.
