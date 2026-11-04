# 305 — Phase 3 demo: every quantity, every kind

## Current behavior

Nothing exists. Needs `301`–`304`.

## Intended behavior

**A table of analogies, generated and then viewed.**

`issues/completed/demos/phase-3-demo` runs every fixture hover through the
analogy datapath, re-rolling each until `exhausted`, and writes the results as
JSON; an HTML page draws them and opens in Firefox.

Rows are fixture quantities, columns are kinds; each cell holds the sentence
and the count, or is empty where the kind had no drawable candidate. Under the
table:

- per kind, how often the model chose it first when it was available
- per hover, how many re-rolls it took to exhaust
- the reference catalogue's coverage report from `301`, as a bar per dimension
  showing the SI range where drawable candidates exist
- how many model replies were rejected by the checker, and why

## Suggested implementation steps

1. The data generator, using the host's modules directly (no Firefox).
2. The viewer page.
3. The demo script; check `run-phase-demo` lists and runs it.

## Related

needs `301`, `302`, `303`, `304`
