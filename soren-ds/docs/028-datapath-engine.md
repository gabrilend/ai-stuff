# Datapath: a value's journey through the engine

The path a value takes from the moment one box returns it to the moment
the next box is running on it — the engine's central path (issue 211),
told as data moving between structures. Every step names the file that
does it. The design reasoning lives in the issues; this page is the
route map.

## The structures a value passes through

| structure | lives in | what it holds |
|---|---|---|
| a task | `035-tasks.c` | one run: the box, the station, the chosen exit, copies of the inputs, room for the return value |
| an exit's destination list | `033-stations.c` | an immutable array of {station, port}; swapped whole on rewire |
| a port's cells | `034-ports.c` | each cell: a four-state word (empty, reserved, ready, claimed) and the value's bytes |
| a station's pending-check count | `034-ports.c` | how many readiness checks were asked for while one was running |
| the task ring | `030-task-ring.c` | pointers to tasks waiting for a core |
| a core's context | `031-engine-internal.h` | which station it runs, its epoch (odd inside a task), counters |

## The steps

```
  core A has just run a box; the return value is in the task
      │
  1   choose the exit                036 exit table, by the station's kind
      │                                (an iterator's exit was chosen at claim time)
  2   read the exit's list once      036 deliver_task — no lock; nobody edits it
      │
      │  for each {station B, port p}:
  3   look at B's state              036 deliver_value — removed or parked: discard, count
  4   write by p's tag               036 write table:
      │     ring   → take an empty cell (compare-and-swap), copy, mark ready
      │     static → the dial, under B's lock, sequence-numbered
      │     none   → a cell, kept for later; no check
  5   B's readiness check            034 station_check:
      │     raise B's pending count; if it was already raised, leave —
      │     the core checking will look again on our behalf
  6   claim in port order            034 claim: one ready cell per ring port,
      │     or give everything back
  7   build a task                   035 task_build: copy the claimed values out,
      │     mark the cells empty, count the run as in flight
  8   push it                        030 ring_push under the ring's lock
  9   wake a parked core, if any     032 engine_wake_sleepers
      │
  core C pops the task, runs the box, and the path starts again at 1
```

## What never happens on the path

- **No lock** except the ring's, for a handful of instructions at step 8.
- **No allocation** except the task at step 7, from core A's own blocks
  (`029-blocks.c`).
- **No copying of a port**: growth appends a page (`port_grow`), and the
  list of pages is replaced whole when it fills, with the old one sent to
  the scrapyard.
- **No freeing of anything a core might still read**: replaced lists,
  removed stations and old page lists go to the scrapyard
  (`033-stations.c`) and are freed only when every core's epoch shows it
  has moved on.

## Where the numbers are

The cost of this path per run is on the measurements page: "what one run
costs" (`endurance-run-cost` in docs/027), and how it scales with cores
(`endurance-speedup`).
