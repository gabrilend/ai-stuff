# 302 — Kinds of subject

## Current behavior

Nothing exists. Needs `301`.

## Intended behavior

**Kinds are families of reference objects, and the host remembers which kinds
each hover has already been shown.**

The vision: when the reader doesn't understand, "the system would create them a
new picture with a different *kind* of subject". A different flour sack is not
a different kind. A horse after a flour sack is.

The kinds are a fixed list in the catalogue file — at least animals, food,
vehicles, buildings and rooms, the human body, sport, household objects,
nature (trees, rivers, mountains) — with a sentence each saying what belongs.
Every catalogue entry names one.

**The memory of shown kinds is per hover**, keyed by `hover_id`, and is a list
of kind names (strings) in the order shown. It lives only as long as the hover:
when `left` arrives, it is dropped. A reader who comes back to the same
quantity later starts fresh.

**Kinds can also be chosen *for*,** not only avoided: some kinds suit some
dimensions better (vehicles for force and speed, rooms for area). An optional
per-kind list of preferred dimensions lets `303` offer those first.

## Suggested implementation steps

1. Add the kinds table to the catalogue file; check every entry names one.
2. `src/` — the shown-kinds memory: start, record, read, drop.
3. Filter the candidates from `301` by "kind not yet shown".
4. Tests: showing every kind in turn for one quantity empties the candidate
   list in exactly as many steps as there are kinds with drawable candidates.

## Related

`docs/004-datapath-the-analogy.md` · needs `301` · blocks `303`, `304`
