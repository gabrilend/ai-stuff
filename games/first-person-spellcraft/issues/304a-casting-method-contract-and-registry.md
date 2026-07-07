# 304a — Casting-method contract & dispatch registry

> Phase 3 · Spell System · sub-issue of
> [304](304-casting-method-dispatch.md). The stable machinery every casting
> method plugs into. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 3.

## Current Behavior

None of this exists yet. There is no agreed shape for a casting method and no
table to hold them, so a cast request's chosen method cannot be looked up or run.

## Intended Behavior

There is a **dispatch table keyed by method key** — the single place methods
register and the single place a cast request is routed. No `if method == ...`
chains anywhere; adding a method is adding a row.

Each method entry advertises:
- **static traits** the rest of the system reads without running the method:
  *needs aim?*, *charges over time?*, *how many hands?* (the two-hand tie to
  Phase 2), and any resource/gem hints for later phases,
- a **handler** — the route that turns a validated cast request into a **resolved
  cast**: it confirms the method is legal for the named spell (cross-checks the
  template's legal-method list from 302), enforces its traits (e.g. refuse if it
  needs aim and none is present — no straight-ahead fallback), applies method-
  specific behaviour (e.g. a charge method's timing/threshold), and emits a
  resolved cast the effect stage can consume.

A **resolved cast** is the neutral hand-off structure: it names the spell, the
caster, and the aim (if any), stripped of *how* it was invoked — Stage 4 should
not care which method produced it.

Registration **refuses collisions and malformed entries loudly** rather than
overwriting silently — a duplicate method key is a bug to surface.

## Suggested Implementation Steps

1. Define the **method-entry structure**: method key, static traits, handler.
2. Define the **resolved-cast structure**: spell reference, caster, aim (if any),
   plus any method-produced parameters Stage 4 legitimately needs (e.g. a charge
   level), kept minimal and method-agnostic in shape.
3. Build the **dispatch table** and its operations by role: *register a method*
   (rejecting duplicates), *look up a method*, *dispatch a cast request* (find
   handler, run it, return a resolved cast or a clear refusal).
4. Write shared validation the handlers reuse: *is this method legal for this
   spell?*, *is aim present when required?* — so each 304b method stays small.
5. Add a `.info.md` documenting the contract so a method author reads it, not the
   registry source.
6. Leave comments on each control-flow branch (aim present vs absent; method legal
   vs illegal) recording what each path means, per project discipline.

## Data Structures / Functions / Files (by role)

- *Method entry* — key, static traits, handler.
- *Resolved cast* — the neutral method-agnostic hand-off to Stage 4.
- *Method dispatch table* — register / look up / dispatch operations.
- *Shared method validation* — legality + aim-presence checks.
- Files: a casting-method registry module under `src/` + `.info.md`.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 3.
- [303](303-cast-request-and-aim-intent-seam.md) — supplies the cast request.
- [302](302-spell-template-data-model.md) — templates list legal methods.
- Blocks: 304b (methods register here), 305a (consumes resolved casts).
