# 201 — A map inside a box

| | |
| --- | --- |
| Phase | 2 — Maps of maps, and history |
| Blocked by | 102 |
| Blocks | — |
| Reads | [the org map, M14](../docs/002-the-org-map.md), [open questions, Q6](../docs/005-open-questions.md#q6--scale) |

## Current behavior

`inside PATH` is checked only for pointing at a directory with an `org.map`.

## Intended behavior

An inner map's doors line up with the ports of the box that holds it: each
`in` port of the box is a door in on the inner map from an outside named after
the parent box's source, and each `out` port a door out. The board can then
descend: a blocked box with an inside shows which inner box is the cause.
How the outer map's rules bind the inner one stays open (Q6).
