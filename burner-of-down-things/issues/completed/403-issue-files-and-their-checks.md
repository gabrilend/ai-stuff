# 403 — Issue files and their checks

Reading a blueprint issue file and checking it against the outline
([006](../docs/006-datapath-the-blueprint.md), *an issue file*).

## Current Behavior

Built as `src/044-issue-files.lua`. The shape checks and the house validator are separate calls: the validator runs only once every file of a describe set is on disk, and its "blocker has no file" finding is dropped — the blockers are already checked against the outline, and a neighbour whose own description failed is retried by the machine, not blamed on this issue. The issue name must match the outline's. Checked by tests/047, including the validator passing a fixture issue and refusing to run when missing.

## Intended Behavior

- **Read an issue** (path): its id and name from the file name; its sections
  by `## ` headings (text under each); its Blocked by ids (every three-digit
  id under that heading); its Acceptance commands (each line in the
  Acceptance section's fenced code block, or each bullet in backticks).
- **Check an issue** (issue, outline row): the required sections present
  (Current Behavior, Intended Behavior, Suggested Implementation Steps,
  Acceptance, Blocked by, Covers); Blocked by equals the outline's; at least
  one Acceptance command; the house validator's `--file` check passes on it
  (its findings included when it does not).
- The validator is found at the house path; when it is missing, the check
  refuses, naming it — the machine does not quietly check less.

## Suggested Implementation Steps

1. Reading. **Test:** a fixture issue gives the right sections, blockers and
   commands.
2. Checks. **Test:** a fixture per finding; a good file passes, including the
   validator.

## Blocked by

- 402
