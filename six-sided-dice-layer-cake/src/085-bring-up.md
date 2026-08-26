# 085 — A new cube on a bench

```meta
phase  | 12
issues | 1205
```

**The only blueprint in this project written for a person to follow.** It reads
like one.

## Before power

Coolant loop filled, purged and pressure-tested. Flow confirmed. **The interlock
tested by tripping it deliberately** — an interlock that has never fired is an
interlock nobody has evidence for, and the alternative way to find out is to lose
a cube.

The cube arrives dry (`021`), so filling and purging is part of installation and
not of assembly. **A cube that arrives is not a cube that can be switched on.**

## The ladder

Each rung is reached only from the one below, and each has a pass criterion, a
duration and a named next action if it fails.

```drawing
the rungs [not-dimensioned]

    1  auxiliary up, scan chain answers
    2  remaining domains up, voltages in tolerance
    3  reference locked, frequency measured rather than assumed
    4  reset released, all ten boot steps clear their fault bits
    5  core written and read back, every location, no errors
    6  radial links trained ── record the spare remap count
    7  one descriptor chain by hand: one matrix multiply, one known answer
    8  a layer, then a face's share, then a token
    9  a token compared BIT FOR BIT against a reference implementation
   10  sustained generation at temperature; counters against 080's model
```

## Rung six carries a number worth keeping for life

**The spare remap count at bring-up.** A cube with an unusually high count is a
cube whose bonds were marginal, and it will fail early. Recorded against the
serial number and compared at every service.

## Rung nine is the one that matters

**Bit for bit, against a reference implementation running elsewhere.** Not within
a tolerance.

`043` specified accumulation order, `046` specified widths and rounding, `043`
specified the exponential and `058` carries the rotations — **all of that exists
so that this comparison is possible.** A tolerance turns every future disagreement
into a judgement call, and on a machine with no debugger and no visibility,
judgement calls are the end of debugging.

## Rung ten is where the model gets checked

`080` predicts seven terms and `049` counts all seven. **Bring-up is the first and
best chance to find out which of them was wrong**, and the comparison must be
recorded and fed back rather than merely performed.

## Symbols

```symbols
n_rung        | 1 | given | 10       | rungs in the ladder
t_rung_1_4    | s | given | 300.0    | powering up, locking, releasing reset and clearing the boot steps
t_rung_5      | s | given | 600.0    | writing and reading back every location with patterns
t_rung_6      | s | given | 300.0    | training every link and recording the remap counts
t_rung_7_9    | s | given | 1800.0   | one multiply, one layer, one face, one token, compared exactly
t_rung_10     | s | given | 3600.0   | sustained generation at temperature with the counters read
t_fill_purge  | s | given | 1200.0   | filling and purging the loop, and tripping the interlock
n_action      | 1 | given | 10       | named next actions, one per rung
n_criterion   | 1 | given | 10       | pass criteria, one per rung
t_bringup_max | hr | given | 4.0     | the longest bring-up may take and still fit inside one shift, so that a cube can be woken and handed over the same day
remap_reject  | 1 | given | 0.5      | share of the spare conductors that, if already used at bring-up, rejects the cube

t_bringup     | s | derived | t_fill_purge + t_rung_1_4 + t_rung_5 + t_rung_6 + t_rung_7_9 + t_rung_10 | the whole procedure
t_bringup_h   | hr | derived | t_bringup                       | in the unit a person plans a day around
f_rung_exact  | 1 | derived | t_rung_7_9 / t_bringup            | the share spent on the exact comparison, which is where the value is
n_counter_chk | 1 | derived | n_model_term_d                    | terms of 080's model that rung ten must compare against 049's counters
t_service_est | s | derived | t_service                         | the cube swap time 019 carries as a target, which this procedure is what would time
```

## Constraints

```constraints
C-085-1 | n_action == n_rung           | every rung must have a named next action if it fails. A person at a bench with a cube that stops at rung six should not have to invent a plan, and a rung without one is an incomplete procedure
C-085-2 | n_criterion == n_rung        | and a pass criterion
C-085-3 | t_bringup_h < t_bringup_max | the whole procedure must fit inside half a working day, or a cube cannot be brought up and handed over in one shift
C-085-4 | n_counter_chk == n_model_term_d | rung ten must compare every term of 080's model against a counter. This is what turns the model from a claim into something tested, and it is why 049 was required to provide one per term
C-085-5 | f_rung_exact > 0.1           | a meaningful share of bring-up must be spent on the exact comparison, because everything specified about accumulation order, widths, rounding and the exponential exists only to make it possible
C-085-6 | remap_reject < 1             | a cube must be rejected while some spares remain, not when they are exhausted -- the count at bring-up is a predictor of early failure and waiting until none are left is waiting until it has already happened
```

## What is still open

**The reference implementation does not exist.** Rung nine compares against
something running elsewhere, and nothing in this project specifies it. It is the
second substantial piece of software the design assumes and does not describe,
after `058`'s packer — and `085` needs both on day one.

**Nothing says what a failure at rung nine means.** The comparison is exact, so a
mismatch localises to an operation; which operation, and what to do about it on a
sealed cube, is not written.

**`t_service` is still a target** carried by `019`, and this is the procedure that
would let it become a measurement.
