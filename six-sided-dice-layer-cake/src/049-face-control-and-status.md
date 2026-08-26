# 049 — How anything finds out what a face is doing

```meta
phase  | 6
issues | 609
```

## Why this matters more than it looks

There is no operating system. Nothing here can be attached to with a debugger,
and once a cube is sealed nothing inside it can be probed.

**These registers are the only window into a running machine.** A machine whose
registers do not say enough is a machine that fails in the field with no
diagnosis, so this blueprint is written from that end: start with the list of
things that can go wrong, and provide something that reports each.

## The groups

**Identity and configuration.** Which face this is, its sieve index, which layers
it owns, the model's shape, the batch. Written at load, read constantly.

**Run control.** Start, stop, reset, throttle level. Written by a host or by
`026`'s thermal interlock.

**Progress.** Which layer, which descriptor, how many tokens completed. Read-only,
and the only way anything outside knows the machine is alive rather than hung.

**Faults.** `043`'s two traps, every error `040` corrected or failed to correct,
every barrier that timed out, every boot step from `073` that did not complete.
**Sticky**, because a transient that is not recorded is a transient nobody can
chase.

**Physical.** Temperature at several points, supply voltage per domain, link
error counts.

## The sensors, which have a hard requirement

`026` requires **sensor lag shorter than the interval between the throttle
threshold and the fatal one at the worst ramp**. With a three millisecond thermal
constant that is comfortable — but placement is still a requirement rather than a
convenience: a sensor at the edge of a die reports a temperature the hot region
passed through some time ago.

At least one sensor **inside** every region of `041`'s power map above a stated
density. On a checkerboard that means one per engine tile group, not one per die.

## The counters nobody remembers to ask for

Cycles stalled waiting on the link. Cycles stalled waiting on a barrier. Bank
conflicts in the slice. Prefetches that arrived late. Each is invisible without a
counter, each is a plausible reason for the machine being slower than `080`
predicts, and each costs almost nothing.

**Every term in `080`'s performance model must have a counter that measures it.**
That is what turns the model from a claim into a hypothesis somebody can test in
`085`, and it is the requirement this blueprint exists to impose.

## Symbols

```symbols
n_sensor_die  | 1 | given | 16     | temperature sensors on one compute die. Eight was a round number chosen before 041 scattered the array into sixty-four tiles; at eight, three quarters of the hot regions have no sensor near them
t_sensor_resp | s | given | 2.0e-4 | response time of one, its own settling included
w_counter     | bit | given | 48   | width of a performance counter
w_reg_ctrl    | bit | given | 64   | width of one control or status register
n_counter     | 1 | given | 12     | performance counters per face
n_fault_bit   | 1 | given | 24     | sticky fault bits per face
n_reg_ctrl    | 1 | given | 64     | control and status registers per face
n_model_term  | 1 | given | 7      | terms in 080's performance model, each of which must have a counter
t_session     | s | given | 3600   | a working session: the span over which a measurement has to mean something, and therefore the span a counter must not wrap in

n_sensor_face | 1 | derived | n_sensor_die * n_die_face      | sensors on one face
sensor_per_tile | 1 | derived | n_sensor_die / n_tile_engine | sensors per engine tile, which is what decides whether the hot region is actually being watched
t_counter_wrap | s | derived | 2^(w_counter / b1) / f_face   | how long a counter runs at full rate before it wraps
C_ctrl        | bit | derived | n_reg_ctrl * w_reg_ctrl       | the register file
t_sensor_lag  | s | derived | t_sensor_resp + tau_engine / 10 | total lag from the hot region changing to the reading changing: the sensor's own settling plus the time for the change to reach it through a tenth of the engine's thermal constant
```

## Constraints

```constraints
C-049-1 | t_sensor_lag < t_lag_budget    | the sensors must see a temperature change before the machine crosses from the throttle threshold to the fatal one at full power with no cooling. 026 sets the budget and this is where it is met
C-049-2 | n_counter >= n_model_term      | there must be at least one counter per term in 080's performance model. This is the constraint that stops the machine being unmeasurable, and it is enumerated across two blueprints because neither can see the other's list
C-049-3 | t_counter_wrap > t_session    | a counter must run for a whole working session at full rate without wrapping, or a measurement taken over one means nothing
C-049-4 | sensor_per_tile >= 0.25        | there must be a sensor for every few engine tiles, so that the hot region on a checkerboard is actually near one rather than merely on the same die
C-049-5 | n_fault_bit >= n_trap + n_boot_step | there must be a sticky bit for every trap and every boot step, so that a machine stopped part way through waking up says which step it stopped in
C-049-6 | n_sensor_face > n_die_face     | more sensors than dies, which is the weakest possible statement of the placement requirement and catches somebody putting one per die and calling it done
```

## What is still open

**The counter list is a number and not a list.** `C-049-2` counts twelve against
seven, which proves there are enough counters and nothing about whether they
measure the right things. The notation cannot hold a list of names to be matched
against another list of names, so the actual correspondence between `080`'s terms
and these counters exists only in prose.

**Nothing reports an out-of-range address.** `038` notes that a face computing a
wrong address reads somebody else's region and produces plausible nonsense. There
is no fault bit for it here because there is no mechanism to detect it, and
adding one means adding bounds checking to a machine that has deliberately none.

**The registers are reachable through the port field and nothing says what
speaks to them.** `085` assumes a host throughout and `069a` is where that host
attaches, and the two have never been made to agree on a protocol.
