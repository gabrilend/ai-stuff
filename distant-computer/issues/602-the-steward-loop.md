# 602 — The steward loop

phase 6, the steward

## Current behavior

Nothing exists.

## Intended behavior

`scripts/steward` on the distant computer, the loop in
`docs/datapath-steward.md`: read settings and state, check budget, hand
answers back, pick work, run one headless Claude Code turn on
`distant-work`, file a `commit` request for each finished commit, record
cost, write a receipt, pause, loop.

Picking work uses `validate-issues` and `progress-dashboard.lua` from the
monorepo's `scripts/` (they are in the clone), in the order the datapath
gives. `input/steward` lists the projects in reach and any priority issues.

After an approved commit comes back on `main`, the loop rebases
`distant-work` onto it before the next turn. A rebase conflict becomes a
`decision` request and the loop moves to another project.

## Suggested implementation steps

1. Pick work, as a pure function of the issue tree and settings, tested on a
   copy of a real project.
2. The turn runner wrapping `claude -p`, with its output saved to the run
   log.
3. Request filing per commit (shared with 304 so a commit gets exactly one
   request).
4. The rebase step.

## Related documents

- `docs/datapath-steward.md`

## Blocked by

101, 201, 304, 501, 601.

## Blocks

603, 604, 605, 701.
