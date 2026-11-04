# 007a — The shape words

**Phase:** 0 — Tools
**Parent:** 007
**Blocks:** 007b

## Current Behavior
Built. `docs/shape-words.md` (the contract) and `src/012-the-shape-words.lua`
(the tables), equal word for word by a test in `src/017-the-word-tests.test.lua`.
Beyond the first plan: `plate` (a thin box), "faces forward / faces up /
faces sideways" for flat things (a plate's axis is the way it faces; found
when the crown's panel, said to "stand upright", lay flat), and `it` ("the
lens is half as deep as it is wide", needed for the owner's rectangular
lenses). Units: a part of any kind with no size sentence is 1 wide.

## Intended Behavior
Two halves that must not drift apart:
- **document**: docs/shape-words.md — every kind of solid, dimension word,
  ratio word, comparative, colour, placement phrase and sentence shape, and
  every default (a default printed there is vocabulary; one only in code is
  a fallback, which is an error).
- **table**: src/012-the-shape-words.lua — the same, as Lua tables the
  reader dispatches on.
A test reads the document and checks every word in the table appears in it,
and every word the document lists as a word is in the table.

The kinds: box, cube, cylinder, disc, rod, sphere, ball, cone, ring. Every
part has an **axis** (default upright) and three extents: **along** the axis,
**across** it (width), and **deep** (the second across; round kinds keep
width and deep equal; cubes and spheres keep all three equal).

## Suggested Implementation Steps
1. Table; document; the agreement test.
