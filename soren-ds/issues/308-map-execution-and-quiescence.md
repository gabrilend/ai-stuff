# 308 — Map execution and quiescence

## Current behavior

A loaded map (303) with wires hooked (304), encaps spliced (305),
cycles checked (306), and routing dispatch hooked (307) is ready
to *run* — but nothing yet starts it. The threading core's
gathering function only fires boxes whose input slots already
have queued values; a freshly loaded map has empty slots, so
nothing happens.

## Intended behavior

`map_run(map_t *)` submits one initial task per entry box. Entry
boxes are the read boxes the map's `meta.json` named — their
output is a literal value or the bytes of a path-referenced file.
The submitter:

1. For each entry box, build a `task_t` (203) whose box
   descriptor is the entry box's, whose input array is empty
   (read boxes have no inputs), and whose return slot is the
   entry box's unique return slot.
2. Push each task onto 204's work queue.
3. Wake any idle workers via 210's notify mechanism.

Once the entry tasks are in flight, the runtime steady-state
takes over: workers run boxes, the routing dispatcher pushes
outputs, downstream gathering functions fire when slots fill,
new tasks are queued, more boxes run.

A map reaches **quiescence** when:

- The map's per-map work queue (or the global queue, for phase
  3's single-queue case) has no tasks for boxes in this map.
- No in-flight tasks belong to this map.
- No slots in this map's slot store have queued values waiting
  to fire.

A quiescence-detector function checks the three conditions and
returns a yes/no. The runtime polls quiescence after every fire
that emptied the queue. A quiescent one-shot map (no self-arming
boxes) is done; the runtime can free its allocations or hand it
back to the caller for a result.

A quiescent long-running map (one with a self-arming pattern like
a timer waiting for the next tick) is *temporarily* quiescent; it
re-enters the running state when something external pushes a
value into one of its always-eligible read boxes (a button event,
a peer message, the timer wake from a re-arming routing). Phase 3
ships without those external sources — input drivers come in
phase 5, peer messages in phase 7 — so the phase 3 demo's maps
are one-shot and exit on quiescence.

## Suggested implementation steps

1. `map_run(map_t *)` — entry-box submission.
2. `is_quiescent(map_t *)` — three-condition check.
3. `map_wait_for_quiescence(map_t *)` — block the calling
   thread until the check returns yes.
4. `map_result(map_t *, box_name)` — read the final value of a
   named output box's return slot.

## Related documents

- `docs/012-soramech-runtime.md` — how a map runs section.

## Blocked by

203, 204, 206, 209, 210, 301, 304, 305, 306, 307.

## Blocks

311.
