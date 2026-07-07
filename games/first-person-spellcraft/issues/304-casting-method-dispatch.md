# 304 — Casting-method dispatch (umbrella)

> Phase 3 · Spell System · "there are more than one ways to do each of them."
> Datapath: [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 3.
> Depends on: [303](303-cast-request-and-aim-intent-seam.md) (a cast request to
> consume). Split into sub-issues
> [304a](304a-casting-method-contract-and-registry.md) and
> [304b](304b-initial-casting-method-set.md).

## Current Behavior

None of this exists yet. A cast request (303) names a *chosen casting method*,
but there is nothing that knows what a method *is* or how to run one. The vision
is emphatic that a spell has many casts: "there are many ways to cast spells of
each level in each path. each spell is different, and there are more than one ways
to do each of them" (notes/vision ~111-113).

## Intended Behavior

Casting methods are the **verbs of invocation** — gesture-cast, charge-and-
release, two-hand-combination, and more added over time. They are modelled as a
**dispatch table keyed by method**, the project's standing preference over a
switch statement, and the natural shape here since the method set is explicitly
meant to keep growing.

Given a cast request, the system looks up the chosen method, runs its handler,
and produces a **resolved cast** (or a clear refusal). This umbrella issue frames
two concerns that are deliberately separated:

- **304a — the contract and the registry (stable):** the shape every method
  implements, the traits a method advertises (needs aim? charges over time? how
  many hands?), and the dispatch/registration machinery. This part changes
  rarely.
- **304b — the initial concrete method set (growing):** the first real methods as
  data-driven entries in the table, including the two-hand-combination that ties
  to Phase 2's two hands. New methods land here without touching 304a.

Splitting them keeps the load-bearing dispatch machinery small and stable while
the "more than one way" catalogue grows freely.

## Suggested Implementation Steps

See the sub-issues. In short: build 304a's contract + registry first, then
populate 304b's methods against it; verify a cast request routes through the
table to a resolved cast with no central switch anywhere.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 3.
- [304a](304a-casting-method-contract-and-registry.md),
  [304b](304b-initial-casting-method-set.md) — the split.
- Blocks: 305a (effect resolution consumes the resolved cast a method produces).
