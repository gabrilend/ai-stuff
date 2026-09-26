# 404 — Describing in parallel

Writing every issue file of the blueprint, many turns at once
([006](../docs/006-datapath-the-blueprint.md)).

## Current Behavior

The outline and graph exist; no issue files are written.

## Intended Behavior

- **Describe step** (case): for every outline row with no `described` line
  in the ledger, one `describe` turn, its prompt holding the outline row, the
  whole outline (so it can name its neighbours), the issue file format, and
  the survey rows of its covered files. All run as one set (306).
- Each issue file that comes back is checked (403); passing appends
  `described`; failing gets a new turn with its findings, up to three turns
  per issue; the third failure appends `describe-failed`.
- **Command `describe`**: runs the outline step if there is no `outlined`
  line, then the describe step; prints the graph at the end.

## Suggested Implementation Steps

1. The step with the stand-in on a fixture source. **Test:** every outline
   row ends with a checked file and a `described` line.
2. **Test:** a stand-in script whose describe of one issue is bad twice then
   good: three turns for it, one for the others.
3. **Test:** running `describe` again changes nothing and runs no turns.

## Blocked by

- 403
