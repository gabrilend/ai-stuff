# 10-069: Front-Loaded Pre-Flight Gate — Every Knowable Failure Before the First Stage

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: High (full builds run overnight, unattended)
- **Type**: Feature
- **Status**: IN PROGRESS
- **Created**: 2026-09-22
- **Related**: 10-053 (exclusion validation, `strip-excluded --check`),
  10-065 (explicit CLI values; `validate_supplied_values`), 8-058
  (threading-library failure becomes an error), 8-045 (missing timeline
  entry becomes an error), 10-010 (test suites in the pipeline)

## Summary

A full build takes hours and is run overnight. Owner (2026-09-22): "Ideally,
we'd have the errors appear early on. If we know we're going to be doing the
stages that need the threading library for example, in run.sh we should try
loading the library to see if it works. The earlier we can push errors, the
better. Ideally, they'd all be gated near the front, and if they all pass then
we can feel safe knowing that the build will (probably) run to completion
without anymore input from us."

## Current Behavior

- `scripts/preflight-gate` holds the checks as a list of rows (label, the
  test for whether this run needs it, the check itself). It runs the needed
  rows, prints one line per check, prints every failure with its output, and
  exits 1 if any failed ("No stage was started"). It changes nothing.
- `run.sh` calls it right after `validate_supplied_values`, before this run
  records any state or starts a stage, passing which stages will run
  (`--html-threads N` for stage 9, `--extract` for stage 2). Dry runs are
  checked too.
- Checks so far:
  1. **Threading library** (stage 9 with more than one thread): loads effil
     through `libs/effil-loader.lua`, the same loader the HTML generator uses.
  2. **Exclusion paths** (stage 2): `scripts/strip-excluded --check`.
  3. **Every poem has a date** (stage 9 or 10, when stage 3 is not rebuilding
     the poem list this run): `scripts/check-poem-dates`, which runs the page
     build's own date ordering over `assets/poems.json` (half a second for
     8,531 poems) and names the first undated poem (8-045).
- `scripts/preflight-gate.test.sh` (13 checks): a missing library stops the
  gate and names the check; the real library passes; one worker never checks
  the library; no stages selected prints nothing; an undated poem stops the
  gate and is named; the real poem list passes; a malformed thread count is
  refused.
- Before this issue, `run.sh` refused missing CLI values, a model without
  embeddings and an unreachable inference server up front, but a bad
  exclusion path surfaced only at stage 2 and a missing threading library
  only at stage 9 (where it quietly fell back to one thread, 8-058).

## Intended Behavior

- One pre-flight gate in `run.sh`, run after the CLI values are validated
  and before this run records any state or starts any stage.
- The gate is a list of checks. Each check names the stages that need it
  and runs only when one of those stages is selected. Every selected check
  runs, and all failures are printed together, so one run shows everything
  to fix; then the gate exits non-zero.
- Checks are cheap (seconds) and do not modify anything.
- A passing gate prints one line per check that ran.
- Initial checks:
  1. **Threading library** (stage 9 with more than one thread): effil
     loads from the same search path the HTML generator uses.
  2. **Exclusion paths** (stage 2): `scripts/strip-excluded --check`.
- Later checks are added to the same list as their issues land (for
  example 8-045's "every poem has a timeline entry", 2-010's cache
  fingerprint).

## Suggested Implementation Steps

1. Add `run_preflight_gate` to `run.sh`: a dispatch list of
   (label, selected-when, command) rows; run the selected ones, collect
   failures, print them, exit 1 on any.
2. Call it right after `validate_supplied_values`.
3. Threading check: a one-line luajit that appends the HTML generator's
   effil path to `package.cpath` and requires effil; the path is read from
   one shared place so the check and the generator cannot drift.
4. Exclusion check: `lua scripts/strip-excluded "$DIR" --check`.
5. Test (`scripts/preflight-gate.test.sh`): run the gate with a stage
   selection that needs effil while effil's path is pointed at an empty
   folder; it must exit non-zero, name the threading check, and create no
   run state. With nothing selected that needs a check, it passes silently.
