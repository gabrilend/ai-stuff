# graph.h / graph.c — public surface

The **trigger-on-ready dispatch**: the layer that turns slots + pool into a
living SoraMech map. A box fires when all its input ports hold a value; when it
finishes it wakes the downstream boxes that just became ready; source boxes
re-arm themselves (the frame-clock heartbeat, the iterator loop). No central
loop — boxes waking boxes.

## Model

- A **box** (`box_t`) is a function (`box_fn_t`) plus its input port slots, the
  boxes it feeds (`down[]`, checked for readiness after it runs), and an atomic
  `in_flight` gate. `user` holds box-specific state (output slot ids, counters).
- A **wire is a shared slot**: "A feeds B" means A writes the slot that is B's
  input port. There is no separate routing table — the shared slot id *is* the
  wire.
- A **box body** reads its inputs, computes, and pushes its outputs into the
  downstream slots. It returns 1 to keep re-arming (meaningful only for a source
  box — the heartbeat), 0 otherwise.

## API

- `void box_kick(box_t *b)` — spawn a box onto its pool iff not already in
  flight (the single-spawn gate, via an atomic compare-exchange). Used to start
  the graph (kick the source boxes) and internally to fire ready downstream
  boxes.

The dispatch action itself is internal; you interact with the graph by building
`box_t` values (wiring `in[]`, `down[]`, `user`) and calling `box_kick` on the
sources, then letting the pool run (e.g. `pool_wait_quiescent` for a bounded
graph, or run-until-quit for a live game).

## Correctness invariants

- **single-spawn** — a box in flight is never spawned again concurrently
  (`box_kick`'s CAS). A box made ready by two producers at once schedules once.
- **clear-then-recheck** — an input-driven box clears its gate *before*
  re-checking its own inputs, so input that arrives while it runs is never
  missed (the classic trigger-on-ready wakeup race).

## Test

- `graph-test.c` — the self-checking mouse round-trip: `heartbeat → mouse →
  pose`, where the mouse emits differentials deterministic in the tick number, so
  pose's drain-and-summed position is checked against an INDEPENDENT authoritative
  sum. Agreement is only possible if the dispatch conserved every value across
  every thread interleaving. Passes 40/40 under repeated stress.

## Related

- `libs/engine-core/slot.{c,h}` — the slots (wires).
- `libs/task-pool/pool.{c,h}` — the pool (threads) boxes run on.
- `docs/soramech-notes.md` — patterns 3 (drain-and-sum), 6 (heartbeat), 8 (getter).
- Issue `102` — the core loop / lifecycle this dispatch realizes.
