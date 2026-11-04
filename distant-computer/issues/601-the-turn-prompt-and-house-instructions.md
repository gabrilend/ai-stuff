# 601 — The turn prompt and the house instructions

phase 6, the steward

## Current behavior

Nothing exists.

## Intended behavior

What the steward is told each turn (`docs/datapath-steward.md`, "What the
turn prompt says"), built from parts:

- a fixed part, `src/steward-prompt` (tracked, so its changes are reviewed
  like code): the gate, the request format, the outward line, the style
  allowance ("prefer the house style; your own is allowed where you judge it
  better, with a comment saying why");
- a per-turn part filled in by the loop: project, issue, budget left,
  link state, answers received since the last turn.

The provisioner (501) copies `~/.claude/CLAUDE.md` and `~/.claude/skills/`
to the steward's home. A small sync step keeps them current as a courier
step, near → distant, with no approval needed.

## Suggested implementation steps

1. The fixed prompt text.
2. The filler as a pure function of a turn table, with a test.
3. The instructions-sync courier step.

## Related documents

- `docs/datapath-steward.md`

## Blocked by

None.

## Blocks

602.
