# 205 — Slot store with ring-buffered cells

## Current behavior

The gathering function from 206 needs somewhere to look when it
asks "does every input slot of this box have at least one value
queued?" That somewhere is the slot store. It does not exist yet.

## Intended behavior

The slot store is the runtime's memory for values in flight along
wires. Per box, per input port, there is one *slot*. Each slot
contains a small ring buffer of *cells*; each cell can hold one
value at a time.

The slot exposes:

- `slot_push(slot *, value)` — a producer pushes a value into the
  ring's next empty cell. Used when a previous box's output
  arrives along a wire connected to this slot. The push uses
  release ordering (207) so the value's bytes land before the
  cell's occupancy flag is observed by the gathering function.
- `slot_pop(slot *, value *)` — the gathering function pops one
  value from the slot's oldest occupied cell. Used during the
  gathering decision when every slot has at least one value to
  pop.
- `slot_has_value(slot *)` — non-destructive query the gathering
  function uses to decide whether the box is ready to fire.

The ring is small. The minimum useful size is one cell per slot;
phase 2 ships with four cells per slot so a producer can fire
ahead of a consumer without immediately blocking. Iterator and
distributor routing patterns from `012-soramech-runtime.md` drain
queued cells across multiple consumer fires.

The slot store also carries the **unique return slots** from 203.
A return slot is a special slot with exactly one cell — the cell
the task's output value lands in once the function returns. The
release-ordering store on the return-slot cell is what makes the
output visible to downstream gathering functions.

## Suggested implementation steps

1. `struct slot` — ring of N cells, head/tail counters, per-cell
   occupancy.
2. `slot_push() / slot_pop() / slot_has_value()`.
3. `slot_store_init()` — allocate slot storage for a given map
   from 108's heap, sized from the map's box count and input
   port count.

## Related documents

- `docs/003-threading-model.md` — the slot semantics section.
- `docs/012-soramech-runtime.md` — how the runtime layers slot
  state into firing decisions.

## Blocked by

108, 203, 207.

## Blocks

206, 209.
