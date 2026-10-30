# 047-nearest — the nearest legal word to a miss

Both walls teach the same way: when a name misses its vocabulary, they
quote back the closest legal word by edit distance. This is that measure,
taken out of `024-compile.lua` so the 2D wall and the 3D wall share one
copy.

## Usable surface

- **edit_distance(a, b) → n** — Levenshtein distance between two strings.
- **word(miss, candidates) → word** — the candidate nearest the miss. Ties
  go to the one met first, so a sorted list gives a steady answer.

Used by `024-compile.lua` (by `require`) and `049-shape-wall.lua` (by
`dofile`).
