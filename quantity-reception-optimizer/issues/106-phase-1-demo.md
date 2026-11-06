# 106 — Phase 1 demo: hovers painted as heat

## Current behavior

Nothing exists. Needs `101`–`105`.

## Intended behavior

**A demo that shows what phase 1 reads, as numbers and as a picture.**

Run by `issues/completed/demos/phase-1-demo`, which runs a Lua program over
every saved hover record and writes one HTML page into `tmp/shared-memory/`,
then opens it in Firefox. Generation (the Lua program writing a data file) and
viewing (the HTML page drawing it) are separate pieces.

The page shows, for each captured hover:

- the paragraph as it wrapped when captured, each word tinted by its weight,
  once under *encouraged* and once under *discouraged*, side by side
- the found quantity outlined, with its value, unit, dimension and SI value
  beneath
- or "no quantity here", when that was the answer

And at the top, totals across the fixtures: quantities found, missed, found
wrongly (from `102`'s test file), units in the lexicon by dimension, and the
average share of total weight that falls outside the quantity's own sentence
under each policy — the single number that says how much the policy changes.

## Suggested implementation steps

1. The data generator: hover records in, one JSON file of results out.
2. The viewer: a static HTML page that reads that JSON and draws it.
3. The demo script, which rebuilds the RAM folders behind `tmp/` first.
4. Check `run-phase-demo` at the project root lists and runs it.

## Related

needs `101`, `102`, `103`, `104`, `105`
