# 609 — How anything finds out what a face is doing

Produces `src/049-face-control-and-status.md`.

## Current behavior

Nothing. `307` needs temperature sensors with a specified lag and none exist.

## Intended behavior

**Every register a face exposes, what writes it, what reads it, and what happens
when it changes** — plus the sensors behind the ones that report physical
quantities.

### Why this matters more than it looks

There is no operating system. Nothing on this machine can be attached to with a
debugger, and once a cube is sealed nothing inside it can be probed. **The control
and status registers are the only window into a running machine**, and a machine
whose registers do not say enough is a machine that fails in the field with no
diagnosis.

The blueprint should be written from that end: start with the list of things that
can go wrong, and provide a register for each.

### The groups

**Identity and configuration.** Which face this is, its sieve index from `010`,
which layers it owns, the model's shape, the batch size. Written at load, read
constantly.

**Run control.** Start, stop, reset, throttle level. Written by the host or by the
thermal interlock, read by the sequencer.

**Progress.** Which layer, which descriptor, how many tokens completed. Read-only,
and the only way anybody outside knows the machine is alive rather than hung.

**Faults.** The two traps `603` permits, plus every error `507` corrected or failed
to correct, plus any barrier that timed out. **Sticky**, so a fault that occurred
and cleared is still visible, because a transient that is not recorded is a
transient nobody can chase.

**Physical.** Temperature at several points, supply voltage per domain, link error
counts.

### The sensors, which have a hard requirement

`307` requires that **sensor-to-hot-spot lag be shorter than the interval between
the throttle threshold and the fatal one at the worst load ramp.** A sensor at the
edge of a die reports a temperature the hot region passed through milliseconds
ago, and milliseconds are long compared to the transient in `307`.

So placement is a requirement, not a convenience: at least one sensor **inside**
the matrix engine region identified by `601`'s power map, not merely on the die.
The blueprint must derive the count and the placement from the lag requirement and
`601`'s map, and must state the sensor's own response time, which is not zero.

### The counters nobody remembers to ask for

Cycles stalled waiting on the link. Cycles stalled waiting on a barrier. Bank
conflicts in the slice. Prefetches that arrived late. Each of these is invisible
without a counter, each is a plausible cause of the machine being slower than
`1106` predicts, and adding them costs almost nothing. **Every performance question
somebody will ask in `1205` should have a counter that answers it**, and the
blueprint should be written by going through `1106`'s model term by term and
providing one per term.

## Symbols this must publish

Register map: address, width, access, reset value, and meaning for each. Sensor
count, placement, response time and accuracy. Sensor-to-hot-spot lag. Counter list
and widths. Sticky fault bit list.

## Constraints this must assert

- Sensor lag is under `307`'s requirement at the worst ramp.
- At least one sensor lies inside every region of `601`'s power map above a stated
  density.
- Counter widths do not wrap within a stated observation window at full rate.
- Every term in `1106`'s performance model has a counter that measures it.
  Enumerated across the two blueprints, which is the constraint that stops the
  machine being unmeasurable.

## Suggested implementation steps

1. Start from the failure list, not the register list.
2. Lay out the map with a reset value for every field.
3. Derive sensor count and placement from `307` and `601`.
4. Walk `1106`'s model and add a counter per term.
5. Make the fault bits sticky and say what clears them.

## Blocks

`307`, `1204`, `1205`, `1206`.

## Blocked by

`601`, `307`, `1106`.

## Related documents

`085` is the bring-up procedure that will use every one of these.
