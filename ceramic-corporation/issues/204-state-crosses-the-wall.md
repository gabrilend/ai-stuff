# 204 — State crosses a box's wall

| | |
| --- | --- |
| Phase | 2 — Maps of maps, and history |
| Blocked by | 201 |
| Blocks | — |
| Reads | [the org map, maps inside boxes](../docs/002-the-org-map.md#maps-inside-boxes), [open questions, Q10](../docs/005-open-questions.md#q10--state-across-a-boxs-wall), [what blocked means](../docs/004-what-blocked-means.md) |

## Current behavior

Each map's `org.state` stands alone. The outer map can say `fed making.spec`
while the inner map's `cutting.spec`, the door that port leads to, reads
unfed; and a box with a map inside is done whenever a `done` line says so,
whatever its inside says. The board, looking inside a source, trusts the inner
state alone.

## Intended behavior

As decided in Q10, state crosses the wall both ways, worked out when the maps
are read and never written twice:

- **Down:** when a box's `in` port P is fed (a `fed` line in the outer state,
  or a fixed value), every inner door `in X $P` reads as fed. The inner state
  needs no line for it.
- **Up:** when the inner map is finished, the box reads as done. The outer
  state needs no line for it.
- **A new state rule (S5):** a `done` line for a box that holds a map is
  refused while its inner map is unfinished.
- The board and the page read the derived state, at every level, so a port
  fed outside is never shown waiting inside.

To settle while building, and to record in the issue's What Happened:

- **What "finished" means for an inner map.** The likely reading: every work
  box inside is done (itself derived, all the way down). A map with no work
  boxes is never finished, since a role is never done (S3). The `done` line
  only exists for work boxes, so a role with a map inside is never marked
  done either way.
- **An inner `fed` line that the outer state already implies.** By the same
  reasoning as S2 — a second source of truth able to disagree with the first —
  it is probably refused, or at least warned about.
- **Where the derivation lives.** Most likely `src/017-inside.lua`, with the
  reader asking it for a box's derived state the way the validator already
  asks it to check the nesting.

## Done when

- Tests show a fed outer port reading as fed inside; a finished inside making
  its box done, two levels down; and S5 refusing a hand-written `done` over an
  unfinished inside.
- The workshop shows it: the workshop gains an `org.state` feeding
  `making.spec`, and `making/org.state` drops its `fed cutting.spec` line,
  which the outer one now implies.
- Docs 002 (rules S5 and the derived state) and 004 (what blocked means across
  a wall) say how it works.
