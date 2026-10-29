# 604 — Waiting mode and the loose area

phase 6, the steward

## Current behavior

Nothing exists.

## Intended behavior

When `link/state` is `waiting`, the loop runs loose-area turns
(`docs/datapath-steward.md`, "Loose-area turn"): a `git worktree` inside
`loose/`, `nice 19`, a prompt saying it is waiting, and Claude Code's own
permissions limited to `loose/` and the outbox for the turn. On the return to
`connected`, one `note`-style `decision` request lists what the loose area
holds now.

The steward's Claude Code settings for a loose-area turn deny writes to the
clone and to each crystallized place, so the rule is enforced by the tool and
not only by the prompt.

## Suggested implementation steps

1. The worktree set-up and tidy-up.
2. Per-turn Claude Code settings built from `input/crystallized` (303's
   reader).
3. The reconnect summary request.
4. A test: a loose-area turn that tries to write the clone is refused.

## Open questions

- What crystallized means (`docs/open-questions.md`, 1).

## Related documents

- `docs/datapath-link.md`, `docs/datapath-steward.md`

## Blocked by

303, 602.

## Blocks

605.
