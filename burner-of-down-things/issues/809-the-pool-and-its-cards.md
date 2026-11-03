# 809 — The pool and its cards

Every asset ever made, kept, each beside a `.card`: what, category, each parameter by name, seed, paintbrush and version, the canvas, and ratings appended one line at a time. A utility counts ([067](../docs/067-datapath-the-studio.md); the canvas-and-paintbrush method).

## Current Behavior

809a-d are built (issues/completed/809a-card-schema.md,
809b-concurrent-append.md, 809c-count-utility.md, 809d-floors.md): a card
beside every asset; ratings appended one line at a time beside it, safe
under two writers at once, resolving to one tier (a person's latest, else
a machine's); counts per category and per tier, read from cards and
ratings alone; and a floor per category whose cost is reported before it
is raised, deleting nothing. What remains is the ends (804, 806-808)
writing a card with every asset they make.

## Intended Behavior

- The pool is a persistent folder (not RAM); nothing in it is ever deleted.
- Five tiers. Ratings by a person first (the "judge once, curate in use" way); a machine grader only once a local vision model is running and its agreement with the owner is measured.
- A count utility: how many per category at each tier, what a floor would leave.
- A floor per category, with its cost in variety said before it is raised.

## Suggested Implementation Steps

1. Cards written with every asset. **Test:** a card holds every field; two appends at once both survive.
2. The count utility. **Test:** counts match the cards; nothing is read from any asset.
3. Floors. **Test:** raising a floor reports how many remain. Done (809d).

## Sub-issues

- 809a — the card schema
- 809b — concurrent append
- 809c — the count utility
- 809d — floors

## Blocked by

- 804
- 806
- 807
- 808
