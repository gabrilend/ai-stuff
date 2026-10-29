# 401 — Placement rules and the placement report

phase 4, placement

## Current behavior

Nothing exists.

## Intended behavior

A module that decides each file's placement (`docs/datapath-placement.md`):
tracked if git tracks it, else the first matching rule in
`input/placement`, else twinned (owned by near) if larger than
`twin-above`, else **unplaced**. An unplaced file is an error, listed in the
placement report, never guessed.

Every placement except tracked comes with an **owning side** (`near` or
`distant`): the rules are `twinned-near`, `twinned-distant`,
`resident-near`, `resident-distant`. The module answers both "which
placement" and "which side owns it", since the second decides what is
crystallized while the link is down (303).

`scripts/placement --report` walks the monorepo's untracked and ignored
files and prints counts and bytes per placement, plus every unplaced path.

## Suggested implementation steps

1. The rule file reader (its own small format, header comment saying first
   match wins).
2. Decide one path; tests for each rule shape.
3. The report, walking with `git ls-files --others` (ignored and not).

## Related documents

- `docs/datapath-placement.md`

## Blocked by

101.

## Blocks

303, 402, 403.
