# 000 — Table of Contents

This is the canonical document index for the 3d-rts project. Add new
documents here when you create them.

## docs/

- [001 — Overview](001-overview.md) — what the game is and how to read in.
- [002 — Mechanics](002-mechanics.md) — game rules in detail.
- [003 — Tech Stack](003-tech-stack.md) — language, renderer, threading.
- [004 — Architecture](004-architecture.md) — modules and threads.
- [005 — Roadmap](005-roadmap.md) — phases and issue listing.
- [006 — Threading Walkthrough](006-threading-walkthrough.md) — six-part
  guided tour of the threading model in 004 (parts 1–4 spec the design,
  5–6 cover implications and implementation/testing).
- [Balance Updates](balance-updates.md) — append-only log of feel and
  numeric tweaks that don't warrant a full issue.

## notes/

- `vision` — the original vision document. Source of truth for intent.

## issues/

- `phase-1-progress.md` — current Phase 1 status.
- `101-…` through `120-…` — Phase 1 work items.
- `401-point-light-system.md` — Phase 4 seed issue (rendering polish).
- `completed/` — finished issues, preserved for reconstructing the
  project from issues alone.

## libs/

- [900 — Task Pool](../libs/900-task-pool.h) — action-array task pool
  with priorities, parking on blocked-target's waiters list,
  promote-on-blocked-requester, and a write-once result-slot table
  with explicit pending/filled disambiguation. Workers run "tasks"
  composed of small atomic action functions. Available, not yet
  adopted by the game; see
  `issues/completed/114-coroutine-pool-library.md` (kept under its
  original filename per append-only convention; the "Design
  evolution" section inside that file documents the four iterations
  from coroutines to the current parked-action-array shape) for the
  rationale.
- `900-task-pool.info.md` — external API summary for the above.

## tests/

- [tests index](../tests/000-index.md) — what's tested and what
  isn't. New tests go here, one per behavior, named after the
  behavior they exercise.
- `run-all.sh` — compile and run every test in numeric order.

## scripts/

- *(empty so far — `scripts/build.sh` arrives in issue 101)*

## Conventions reminder

- Filenames in `docs/` and `src/` are prefixed with a numeric index so they
  read in narrative order.
- Issue filenames follow `{PHASE}{ID}-{descr}.md`.
- Sub-issues use `{PHASE}{ID}{a|b|c}-{descr}.md`.
- Issues are append-only and immutable in spirit; once completed they move
  to `issues/completed/` rather than being deleted.
