# 603 — The update command

Handling every waiting request, one at a time: locate, grade, hold or amend,
rebuild the reach ([008](../docs/008-datapath-the-update.md)).

## Current Behavior

Built as `src/055-updating.lua`, with the `update` command in `src/056-the-update-commands.lua`. The fixture gained three real requests (`tests/fixtures/tiny-notes-requests/`: a count line after listing — surface; tags shown with their # marks — middle; a header line in the notes file — foundation), each with the amended issue and the code a rebuild writes, and the fixture script builds from whatever the case's blueprint now says. Checked by tests/057: under the default hold two requests are done and one held; the rebuilds are exactly their reaches (301; then 201 and 301; then 101 201 202 301 after `--go`); the running design shows all three changes; hold `none` and hold `middle` behave. Also run end to end through the launcher. A locate that never answers fails only its request; a breach stops the run.

## Intended Behavior

- **Waiting requests:** every request with `request-received` and no
  `request-done` or `request-failed`, in age order (phase 7 reorders them by
  the center).
- For each: if it has no `graded` line, locate and grade it. If its grade is
  at or above the case's `hold` setting (default `foundation`) and the run
  was not given `--go`, append `held` and move to the next. Otherwise amend,
  then run the build step (503) with the reach as the rebuild set; all built
  → `request-done`; else `request-failed`.
- `hold` is a field of `case.lua`: `none`, `middle` or `foundation`.
- **Command `update [--go]`**.

## Suggested Implementation Steps

1. **Test:** three fixture requests — one of each grade — with hold at
   foundation: two done, one held; with `--go`: the third done.
2. **Test:** a request's rebuild set is exactly its reach; other issues get
   no turns.

## Blocked by

- 503
- 602
