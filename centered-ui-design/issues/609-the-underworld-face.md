# 609 — The underworld face

**Phase:** 6 — Foes in every direction
**Blocked by:** 601, 301

**Blocks**: 607
**Related documents:** docs/datapath-accordion-view.md (The world is a
sphere), /home/ritz/documents/w7/notes/prehistory ("the monsters were
pushed underground ... Each side can hold their own realms")

## Current Behavior

The map has one face, the surface.

## Intended Behavior

- The sphere's grid has two faces: the surface, and the underworld inside
  it. Every place carries its face.
- The underworld has its own tier bands and terrain, generated from the same
  seed, and its own inhabitants: the monsters pushed below, holding their own
  realm.
- The view shows one face at a time; a painted button switches which face
  the current seat is looking at, and a dial shows which it is.
- Forces cross between faces at gates (assumed: one per tier per quadrant).

## Suggested Implementation Steps

1. Face field on places; second set of tier bands.
2. Gate placement and crossing rule.
3. Face switch button and dial.

## Open questions

- How do the faces connect, and what is at the far pole? (Open question 5.)
