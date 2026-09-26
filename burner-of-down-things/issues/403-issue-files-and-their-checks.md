# 403 — Issue files and their checks

Reading a blueprint issue file and checking it against the outline
([006](../docs/006-datapath-the-blueprint.md), *an issue file*).

## Current Behavior

Nothing reads the blueprint's issue files.

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
