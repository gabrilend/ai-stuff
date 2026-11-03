# 906 — Observations and adjustments

*"so it looks like the sheep are out of the barn because they pushed through the door. Let's make that heavier to move from the other side."* — a result that says something went wrong becomes an observation of the mechanism behind it, and then a change request against the station whose mechanism it is ([068](../docs/068-datapath-the-switchboard.md), *observation and adjustment*).

## Current Behavior

A station's errors are only printed.

## Intended Behavior

- A result holding an error ("error error detected") becomes an **observation**: what happened, and the mechanism that let it happen, written by a turn that reads the result and the station's blueprint.
- The observation becomes an **adjustment**: a request file dropped into the station's own case, which the update step (008) locates, grades, amends and rebuilds like any other.
- An observation that names no mechanism is sent back: a mood is not a mechanism (069).

## Suggested Implementation Steps

1. Observations. **Test:** a stand-in observation without a mechanism is refused; one with a mechanism is kept. Done (src/157-observations.lua, tests/158-checking-observations.lua).
2. Adjustments reaching the update step. **Test:** a station's failing result ends as a graded request in that station's case.

## Decisions

- 2026-11-02, step 1. The mechanism check is the lesson's own (085 `lesson.build`, the 1002c mood check), not a second word list, so an observation and a lesson can never disagree about what a mechanism is. That is why this branch stacks on the strategem drafts (1001→1002→1003), where 085's mood check lives.
- An error is a result line that opens with the word "error" (any case; "errors" and "erroneous" do not count) or a table's non-empty `error` string. A clean result asks no one.
- The observing turn is passed in as `ask(prompt, attempt)`, so tests use a stand-in and no real model runs. Wiring a real turn waits on the turn pool (effil), like 808 step 2.
- An answer is sent back with its reason in the next prompt, at most 3 times (`MOST_ATTEMPTS`); after that the result is `waiting` for the person, never dropped.
- Kept observations are appended, never rewritten, as `## station` sections with a `Mechanism:` line — the same discipline and line shape as lessons, so 1003's drafting could later read them too (not wired; not decided).
- Step 2 (adjustments reaching the update step) stays open: it needs the update step's request path and a station's case folder, which the switchboard's stations do not yet have.

## Blocked by

- 905
- 603
