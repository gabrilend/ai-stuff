# 905d — Plan execution

The fourth piece of 905.

## Current Behavior

Built. `src/127-plans.lua`'s `run(plan, from, wanted, value,
keep_folder)` checks the plan, then runs each station's `run` in order,
keeping each result as a new parcel (079's form, a folder of files:
`result.txt` for text, the record `result.lua` for a table) in
`keep_folder/NN-<station>/`, and hands it to the next. A station that
fails stops the plan, naming it; the parcels before it stay. Checked by
`tests/130-checking-plan-execution.lua`: a two-station plan (a split
station of the test's own, then the real 807a `txt-table` station) runs
end to end and both intermediate parcels are kept and read back with
079's `read`.

Decisions: "recorded" is the kept parcel folder. A ledger line per
station would need a case and a new ledger kind; the router (904), which
runs plans for a case, is where that belongs once it is built.

## Intended Behavior

Running a plan executes each station in order, each result becoming a new
parcel that is recorded and handed to the next station.

## Suggested Implementation Steps

1. The run loop over a checked plan. 2. Recording each intermediate
   parcel. **Test:** a two-station plan runs end to end and every
   intermediate parcel is kept. Done: `run`.

## Blocked by

- 905c
