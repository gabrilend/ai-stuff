# 906 — Observations and adjustments

*"so it looks like the sheep are out of the barn because they pushed through the door. Let's make that heavier to move from the other side."* — a result that says something went wrong becomes an observation of the mechanism behind it, and then a change request against the station whose mechanism it is ([068](../docs/068-datapath-the-switchboard.md), *observation and adjustment*).

## Current Behavior

A station's errors are only printed.

## Intended Behavior

- A result holding an error ("error error detected") becomes an **observation**: what happened, and the mechanism that let it happen, written by a turn that reads the result and the station's blueprint.
- The observation becomes an **adjustment**: a request file dropped into the station's own case, which the update step (008) locates, grades, amends and rebuilds like any other.
- An observation that names no mechanism is sent back: a mood is not a mechanism (069).

## Suggested Implementation Steps

1. Observations. **Test:** a stand-in observation without a mechanism is refused; one with a mechanism is kept.
2. Adjustments reaching the update step. **Test:** a station's failing result ends as a graded request in that station's case.

## Blocked by

- 905
- 603
