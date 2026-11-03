# 103 — The blocked board

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 102 |
| Blocks | 105, 106 |
| Reads | [what blocked means](../docs/004-what-blocked-means.md) |

## Current behavior

Whether a box is blocked can be computed (102) and nothing ranks what is
blocking.

## Intended behavior

`blocked-board ORG` prints one row per source of waiting — owes, frees, reach,
whether it can act now, and its holders — ranked by reach, then frees, then
can-act-now, then name. `--ready` shows only sources somebody can deliver
today. Loops are walked with a visited set.

## Suggested implementation steps

1. Compute the waits and their sources from the reader.
2. owes and frees by one pass over the waits.
3. reach by walking "depends on" backwards from each source, visited set.
4. The ranking, and a plain-text table.
5. Tests: the bakery's board as printed in document 004; a chain of ten where
   the bottom frees one and reaches nine; a loop that terminates.
