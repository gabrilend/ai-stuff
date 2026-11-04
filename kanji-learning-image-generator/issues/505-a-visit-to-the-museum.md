# 505 — A visit to the museum

## Current behavior

Phase demos exist for phases 1–4 under `issues/completed/demos/`, chosen from
`run-demo` at the project root. There is no phase-5 demo.

## Intended behavior

**The phase-5 demo is a walk through the halls**, as a page opened in the
browser. For a handful of characters it shows:

- each character in its hall, **inside and outside** (`416`) side by side, and
  beside the same character in the plain photographic style, so the hall's
  effect is visible by comparison
- for each picture: the hall chosen and its score against the runners-up, the
  route, the kitchen and checkpoint, and — for the inside route only — the
  machine grader's correlation
- across the set: how many characters landed in each hall, how many fell back
  because a museum lacked their best hall, how many matched nothing
- the planetarium given its own room

It reuses earlier phases rather than describing them: `304`'s gallery pages the
pictures, `405`'s pool supplies them, `406`'s grader scores the inside ones, and
`408`'s stroke-order animation plays over any a person rated highly.

## Suggested implementation steps

1. A demo script in `issues/completed/demos/` running a fixed small set and
   writing the page into `tmp/shared-memory/`.
2. `run-demo` offers phase 5.
3. `issues/phase-5-progress.md` updated as each of `501`–`504` completes.

## Related

`501`–`504`, which this is the capstone of. `416`, whose two routes it shows.
`304`, `405`, `406`, `408`, which it reuses.
