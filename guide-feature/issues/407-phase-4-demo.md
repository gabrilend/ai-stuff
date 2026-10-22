# 407 — Phase 4 demo: three thinkers, three backends, one page

phase 4, the thinkers

## Current behavior

Phase 3's demo shows scripted voices through rmail once 305 is done.

## Intended behavior

`issues/completed/demos/phase-4-demo` runs three thinkers on kuvalu
through the rehearsal mailboxes, each on a different backend where possible
(local small model, remote-llama on the GTX 1080 Ti, and remote-api if the
owner has chosen one), and shows:

- fit tries and give-ups per backend: how well each model respects the box;
- seconds and tokens per turn per backend;
- how many frames each thought survived, and how often voices carried each
  other's thoughts;
- the page itself, live, in a terminal at the box size.

## Suggested implementation steps

1. The run script, starting everything from phases 1–3 plus the thinkers.
2. Fill in `issues/phase-4-progress.md` and add phase 4 to `run-phase-demo`.

## Related documents

- `docs/roadmap.md`, phase 4

## Blocked by

402, 406.

## Blocks

None.
