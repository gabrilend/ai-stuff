# 307 — Routing dispatcher

## Current behavior

The worker scheduling loop from 209 pushes a fired box's output
to every wire on its `connections[]` list. That is correct for
the `plain` routing kind — fan to every wire — but wrong for the
other six kinds, where the routing config determines *which* of
multiple branches the value goes to. The runtime currently treats
every `call` box as if it were `plain`.

## Intended behavior

A routing dispatcher sits between the worker's "box returned a
value" point and the actual slot pushes. The dispatcher reads
the box instance's routing config and walks each of the seven
routing kinds:

- **`plain`** — every wire receives the value. Trivial.
- **`comparator`** — read the value as a numeric, compare against
  a single threshold or a sorted thresholds array, pick one of
  the named branches (`lt`/`eq`/`gt` for the single-threshold
  flavour; `below_X`/`between_X_Y`/`above_X` for multi-band).
  Push to wires whose `from_branch` matches.
- **`iterator`** — round-robin across `n_outputs` ports named
  `out_0`...`out_(N-1)`. Per-box-instance counter increments on
  each fire, mod N, picks the branch. The counter is atomic
  because every box is multi-spawn.
- **`randomizer`** — hash the per-box counter, mod N, pick the
  branch. The hashed pick smooths consecutive picks so the
  sequence does not bias toward adjacent indices.
- **`weighted`** — cumulative-weight lookup against the box's
  `weights` array. Each fire picks one branch; the dispatch
  normalises weights at load time so the runtime checks against
  pre-computed cumulative thresholds.
- **`distributor`** — sample the slot fill on every downstream
  branch's first consumer, pick the branch whose consumer has
  the fewest queued values. Ties broken by the same per-box
  counter the iterator uses. The slot fill read is best-effort
  — values can land between the read and the push — but the
  dispatcher is correct under all such races; the worst case is
  a slightly-uneven distribution, not a missed value.
- **`nonlinearity`** — single output. Read the value as numeric,
  feed into a per-box ring buffer (the `memory` field sizes it),
  compute auto-calibrated min/max from the ring, normalise the
  input to that range, apply an S-curve (tanh for `signed`,
  sigmoid for `unit`), emit `input × score` on the wire. The
  ring update is atomic; the curve math is pure.

For each kind, the dispatcher selects the branches that should
receive the value and pushes to each selected wire's slot using
the slot's `slot_push` from 205.

Routing-kind state (the iterator counter, the distributor's
last-tie-breaker, the nonlinearity ring) lives on the
`box_instance_t` per instance, not on the descriptor — two
instances of the same descriptor in two maps have independent
state.

## Suggested implementation steps

1. `dispatch_output(box_instance_t *, value)` — top-level entry.
2. `dispatch_plain()`, `dispatch_comparator()`,
   `dispatch_iterator()`, `dispatch_randomizer()`,
   `dispatch_weighted()`, `dispatch_distributor()`,
   `dispatch_nonlinearity()`.
3. Per-instance state inits in the loader from 303 — the
   loader knows the routing kind and allocates the right state
   shape.
4. Replace 209's plain push with this dispatcher.

## Related documents

- `docs/012-soramech-runtime.md` — routing kinds section.
- `/home/ritz/programs/sora/soramech/docs/002-map-model.md` —
  parent project's routing kind reference.

## Blocked by

205, 209 (the dispatcher replaces the push step there), 301.

## Blocks

308, 311.
