# 905b — Shortest-chain search

The second piece of 905.

## Current Behavior

Built. `src/127-plans.lua`'s `find(rows, from, wanted)` is a
breadth-first search over 905a's shape graph, edges tried in row order so
the same table always gives the same plan; it returns the shortest chain
of station rows, or nil and a sentence naming the type that cannot be
reached, whether any station gives it at all, and what can be reached
instead. Checked by `tests/128-checking-shortest-chains.lua`:
`integer-array + text → image` becomes `table → chart → png` through a
fixture table shaped like 902d's, the shorter of two possible chains; the
real station table feeds the search unchanged.

Decisions: several inputs are one shape written with `+`, compared in a
canonical form (parts trimmed and sorted), so a station row keeps 902d's
one `input` string and `text + integer-array` plans the same as
`integer-array + text`. The fixture's `canvas` shape (what a chart word
hands the painter) is not on 902's closed type list; the search works on
whatever shapes the rows name, and whether the closed list gains it is
for the day the `.png` end (804) joins the real table.

## Intended Behavior

Given a starting shape and a wanted shape, the shortest chain of stations
whose joints fit, found by search over the shape graph — no model
involved.

## Suggested Implementation Steps

1. A breadth-first search over 905a's graph. 2. The impossible-shape
   case, naming which type cannot be reached. Done: `find`. **Test:**
   `integer-array + text → image` becomes `table → chart → png`; an
   impossible shape says which type cannot be reached.

## Blocked by

- 905a
