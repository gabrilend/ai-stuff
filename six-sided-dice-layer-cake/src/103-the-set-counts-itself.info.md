# 103-the-set-counts-itself — info

*Written by hand, not generated. `096` produces companions for blueprints; the
instruments have none, which is recorded in `009` as a gap.*

**The blueprint set's own size** — phase 14.
Described by `1411`, which is the ticket for the kind of value this produces.

## Why it exists

Two blueprints are about the project rather than about the machine. `087` asks
whether every number produced in one phase is checked where it is consumed in
another, and needs to know how many blueprints and constraints there are to say
anything about the ratio. `090` is the covering note a materials engineer opens
first, and it says how large the thing they have been handed is.

Both carried those figures as numbers a person had typed, and both had drifted:
the covering note was offering eighty blueprints and five hundred and eight
requirements when the set held eighty-four and five hundred and forty-four.
Nothing had gone wrong with the design — the document was describing an earlier
version of itself, which is what a self-describing document does if nobody
re-counts.

## What it offers

| call | takes | gives back |
|---|---|---|
| `M.count(dir)` | the project root | a table of counts, and the loaded ledger alongside it |
| `M.answers(dir)` | the project root | the six values `087` and `090` declare as `solved`, as quantities |
| `M.report(n, out)` | a count table | the counts in a page, for a person |

Run it directly — `luajit src/103-the-set-counts-itself.lua` — and it prints the
report. It exits non-zero while any symbol is still a `target`, because a
blueprint set with a goal left in it is not a design.

## The count table

Every field is a plain integer.

| field | what it counts |
|---|---|
| `blueprint` | files in `src/` the reader accepted |
| `symbol` | named quantities across all of them |
| `constraint` | relations asserted across all of them |
| `given` | numbers a person chose |
| `measured` | numbers taken from the world — a datasheet, a material property |
| `derived` | numbers an expression in this notation computes |
| `solved` | numbers a program computed because no expression could |
| `target` | goals with no derivation yet |
| `chosen` | `given` plus `measured` — everything nothing computed |
| `worked` | `derived` plus `solved` — everything something did |

A `solved` counts as worked out rather than chosen, and that is a judgement worth
stating: a program produced it and the checker re-runs the program, so it is no
more remembered than an expression is.

## The fixed point

Converting the five self-describing declarations from `given` to `solved` changed
the number of `given` declarations in the project, so the first run after the
change reported the new figures as already stale — by five, which is exactly how
many had just changed kind. The second run settled.

That is a fixed point rather than a defect, and it converges in one pass because
adding a statement about the count changes the count by a known amount. `090` says
so in prose, so that somebody meeting it does not conclude the checker is broken.

## Related

`094` for the ledger it counts. `095` for the drift check that makes the copies
honest. `087` and `090` for the two blueprints that read it. `002` for what
`solved` means.
