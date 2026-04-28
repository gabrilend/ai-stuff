# 000 — Table of Contents

This is the canonical document index for the 3d-rts project. Add new
documents here when you create them.

## docs/

- [001 — Overview](001-overview.md) — what the game is and how to read in.
- [002 — Mechanics](002-mechanics.md) — game rules in detail.
- [003 — Tech Stack](003-tech-stack.md) — language, renderer, threading.
- [004 — Architecture](004-architecture.md) — modules and threads.
- [005 — Roadmap](005-roadmap.md) — phases and issue listing.
- [Balance Updates](balance-updates.md) — append-only log of feel and
  numeric tweaks that don't warrant a full issue.

## notes/

- `vision` — the original vision document. Source of truth for intent.

## issues/

- `phase-1-progress.md` — current Phase 1 status.
- `101-…` through `119-…` — Phase 1 work items.
- `completed/` — finished issues, preserved for reconstructing the project
  from issues alone.

## libs/

- [900 — Coroutine Pool](../libs/900-coroutine-pool.h) — M:N coroutine
  scheduler over pthreads. Available, not yet adopted by the game; see
  `issues/114-coroutine-pool-library.md` for the rationale.
- `900-coroutine-pool.info.md` — external API summary for the above.

## scripts/

- *(empty so far — `scripts/build.sh` arrives in issue 101)*

## Conventions reminder

- Filenames in `docs/` and `src/` are prefixed with a numeric index so they
  read in narrative order.
- Issue filenames follow `{PHASE}{ID}-{descr}.md`.
- Sub-issues use `{PHASE}{ID}{a|b|c}-{descr}.md`.
- Issues are append-only and immutable in spirit; once completed they move
  to `issues/completed/` rather than being deleted.
