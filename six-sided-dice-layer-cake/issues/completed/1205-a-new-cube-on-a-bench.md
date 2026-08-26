# 1205 — A new cube on a bench

Produces `src/085-bring-up.md`.

## Current behavior

**Done.** `src/085-bring-up.md` exists — the only blueprint in the project written
for a person to follow, and it reads like one.

Six constraints. Two of them are about the procedure being a procedure:
**every rung must have a pass criterion and a named next action**, because a
person at a bench with a cube that stops at rung six should not have to invent a
plan.

Rung nine is the one everything else was built for: **a token compared bit for
bit against a reference implementation**, not within a tolerance. `C-085-5`
requires a meaningful share of bring-up to be spent on it, because the
accumulation order in `043`, the widths and rounding in `046`, the specified
exponential and the carried rotations in `058` all exist for no other purpose.

Rung six records the spare remap count **against the serial number, for life** — a
cube with an unusually high count is one whose bonds were marginal.

**The reference implementation does not exist.** It is the second substantial
piece of software this design assumes and does not specify, after `058`'s packer,
and this procedure needs both on day one.

## Intended behavior

**An ordered procedure a person carries out, with a pass criterion at every step
and a named next action when a step fails.**

This is the only blueprint in the project written for a human to follow rather
than for a machine to be built from, and it should read like one.

### Before power

Coolant loop filled, purged and pressure-tested from `308`. Flow confirmed. **The
interlock tested by tripping it deliberately**, because an interlock that has never
fired is an interlock nobody has evidence for, and the alternative way to find out
is to lose a cube.

### The ladder

Each rung has a pass criterion and each is reached only from the one below:

1. Auxiliary domain up. Scan chain from `1204` responds.
2. Remaining domains up in `406`'s order. Voltages within tolerance at `609`'s
   registers.
3. Reference locked, clocks running. Frequency measured, not assumed.
4. Reset released. `1004`'s ten steps complete, each clearing its fault bit.
5. Core written and read back. All sixty-four gibibytes, pattern verified,
   `507`'s error counts at zero.
6. Radial links trained. `702`'s spare remap count recorded — **a cube with an
   unusually high remap count at bring-up is a cube that will fail early**, and
   this number should be kept for its whole life.
7. A single descriptor chain executed by hand. One matrix multiply, one known
   answer, compared bit for bit.
8. A layer. Then a face's whole share. Then a token.
9. A token compared bit for bit against the reference implementation.
10. Sustained generation at temperature. `609`'s counters read and compared
    against `1106`'s model.

### Step nine is the one that matters

**Bit for bit, against a reference implementation running somewhere else.** Not
within a tolerance. `603` and `606` specified accumulation order, widths, rounding
and the exponential precisely so that this comparison is possible, and if it is
not exact then one of those specifications was not followed and the disagreement
localises the fault.

A tolerance turns every future disagreement into a judgement call, and on a
machine with no debugger and no visibility, judgement calls are the end of
debugging. The blueprint must insist on the exact comparison and say why.

### Step ten is where the model gets checked

`1106` predicts seven terms and `609` counts all seven. Bring-up is the first and
best chance to find out which of them was wrong. The blueprint should require the
comparison to be recorded and fed back, not merely performed.

### When a step fails

Every rung needs a named next action. Not "investigate" — a specific thing to
read, a specific thing to try, and the rung to return to. A person at a bench with
a cube that stops at step six should not have to invent a plan.

## Symbols this must publish

The ordered ladder with pass criteria. Expected duration per step. Equipment
required. Reference implementation identification. Remap count expectation and
the threshold above which a cube is rejected. Counter comparison table. Failure
action per rung.

## Constraints this must assert

- Every rung has a pass criterion, a duration and a failure action. Enumerated —
  a rung missing any of the three is an incomplete procedure.
- The reference comparison is exact. Stated as a requirement rather than a
  preference.
- Every counter in `1106`'s model appears in the step ten comparison table.
- Total bring-up duration is under a stated ceiling.

## Suggested implementation steps

1. Write the before-power section, including the deliberate interlock trip.
2. Write the ten rungs with criteria.
3. Write the exact-comparison requirement and the argument for it.
4. Build the counter comparison table from `1106` and `609`.
5. Write a failure action for every rung.

## Blocks

`1301`, `1304`.

## Blocked by

`308`, `406`, `603`, `606`, `609`, `1004`, `1106`, `1204`.

## Related documents

`002` for the checker, which is the equivalent procedure for the blueprints.
