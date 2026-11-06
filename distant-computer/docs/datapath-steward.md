# Datapath: one turn of the steward

The current design. The issues that change it update this file.

## The loop

    steward loop (bash + lua, on the distant computer)
      │
      ├─ read input/steward, input/budget, link/state
      ├─ budget spent past `stop-at`?  → write a `decision` request, sleep
      ├─ waiting?                      → loose-area turn (below)
      ├─ answers/ has new answers?     → hand them to the voice that asked
      ├─ pick work:
      │     1. an issue the owner marked `priority` in input/steward
      │     2. the lowest-numbered open issue in the projects listed
      │        in input/steward, foundation first
      │     3. no issues anywhere → read a project's vision and docs,
      │        draft issue files (as `commit` requests, like any change)
      ├─ run one Claude Code turn, headless:
      │     claude -p "<turn prompt>" in the clone, on branch distant-work,
      │     with ~/.claude/CLAUDE.md and the house skills copied over
      ├─ each finished commit → a `commit` request in the outbox
      ├─ record cost of the turn into the budget ledger
      └─ write output/goodbye.steward, sleep `pause` seconds, loop

## What the turn prompt says

- the project and issue it is working on;
- that the house style (CLAUDE.md) is preferred, and that its own style is
  allowed where it judges it better, with a comment saying why;
- that nothing reaches kuvalu except through a request, and how to write one;
- that outward actions are requests of kind `outward`, never done;
- the budget left.

## Branches

The steward commits only to `distant-work` in its clone. `main` on the
distant computer is only ever written by the courier's push from kuvalu. An
approved `commit` request is cherry-picked onto kuvalu's `main`, which comes
back to the distant `main` on the next visit. The steward then rebases
`distant-work` onto it. So both computers agree on `main`, and
`distant-work` holds only what is still waiting.

## Loose-area turn

Same loop, but the prompt says it is waiting: work only under `loose/`, use
copies of the clone made with `git worktree` inside `loose/`, and write
nothing else.
