# 809 — The pool and its cards

Every asset ever made, kept, each beside a `.card`: what, category, each parameter by name, seed, paintbrush and version, the canvas, and ratings appended one line at a time. A utility counts ([067](../docs/067-datapath-the-studio.md); the canvas-and-paintbrush method).

## Current Behavior

809a is built (issues/completed/809a-card-schema.md): the card schema and a
single write. 809b (concurrent append), 809c (the count utility) and 809d
(floors) are not yet built.

## Intended Behavior

- The pool is a persistent folder (not RAM); nothing in it is ever deleted.
- Five tiers. Ratings by a person first (the "judge once, curate in use" way); a machine grader only once a local vision model is running and its agreement with the owner is measured.
- A count utility: how many per category at each tier, what a floor would leave.
- A floor per category, with its cost in variety said before it is raised.

## Suggested Implementation Steps

1. Cards written with every asset. **Test:** a card holds every field; two appends at once both survive.
2. The count utility. **Test:** counts match the cards; nothing is read from any asset.
3. Floors. **Test:** raising a floor reports how many remain.

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
