# 203 — Task struct and unique return slot

## Current behavior

Workers exist (202) and they have nothing to do. There is no
definition of a unit of work yet — no struct that describes "fire
this box with these inputs and put the output here." Without
that, the queue from 204 has nothing to carry and the scheduling
loop from 209 has nothing to execute.

## Intended behavior

A `struct task` describes one fire of one box. Its fields:

- A pointer to the box descriptor (from 208) the fire executes.
- A small array of input values, one per input port, already
  popped from the slots by the gathering function (206). The
  array size matches the descriptor's input-port count.
- A pointer to the **unique return slot** where the box's output
  value goes once the function returns. Two tasks created from
  the same box firing twice — or from different boxes — never
  share a return slot. This eliminates producer-side write
  collisions by construction.
- A task id, monotonically increasing across the whole system.
  Used for the JSONL ring buffer in `012-soramech-runtime.md`.

The unique return slot is allocated by the gathering function at
task-creation time. It is a single cell in a slot store entry the
gathering function reserves for this task — once the cell is
reserved, no other code can write to it until the task's output
has landed and downstream consumers have read it.

## Suggested implementation steps

1. `struct task` — fields above.
2. `struct return_slot` — single cell, atomic state flag.
3. `task_alloc()` — heap allocation, return slot reservation.
4. `task_free()` — release after downstream consumes.

## Related documents

- `docs/003-threading-model.md` — the unique return slot section.
- `docs/012-soramech-runtime.md` — how the runtime above this
  uses the task struct.

## Blocked by

108 (heap allocation), 202 (workers exist to populate the struct).

## Blocks

204, 206, 209.
