# 805d — The machine drawn by itself

The fourth piece of 805: the machine's own things as the first real
content, per docs/067.

## Current Behavior

Built. `src/136-the-machine-drawn.lua` turns a blueprint graph into a
`diagram`, a center into a `chart` of its heaviest weights, and ledger
lines into a `chart` of lines per kind. The notes fixture's blueprint
lays out with boxes matching its issue ids exactly. Painting the results
waits on 804. Checked by `tests/137-checking-the-machine-drawn.lua`.

## Intended Behavior

The machine's own blueprint graph, center weights and ledger totals drawn
through 805a–805c: a blueprint-graph-to-diagram adapter, a
center-weights-to-chart adapter.

## Suggested Implementation Steps

1. The blueprint-graph adapter (043's graph → `diagram`'s boxes/arrows).
2. The center-weights adapter (→ `chart`'s data/labels). **Test:** the
   notes fixture's blueprint renders as a diagram whose boxes match its
   issue ids exactly. Done.

## Decisions

- Adapters only, in their own file (136): each turns what the machine
  already holds into a canvas word's data, and reads no file itself.
- A box is named by its issue id and shows "id name", so the drawing reads
  without the outline beside it.
- The center chart shows the eight heaviest weights by default, heaviest
  first, in 058's `heaviest` order; every weight in a long case reads as
  noise.
- The ledger's totals are one chart of lines per kind, most first, ties
  by name; its text-table form is the `.txt` end's (807a).
- Rendering to pixels on a file is still 804's (the `.png` end).

## Blocked by

- 805a
- 805c
