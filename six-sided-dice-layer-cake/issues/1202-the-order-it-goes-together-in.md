# 1202 — The order it goes together in

Produces `src/082-assembly-order.md`.

## Current behavior

Nothing. `207` says nothing inside is serviceable and no assembly sequence exists.

## Intended behavior

**The order the cube is built in, which is nearly forced, and the point of no
return in it.**

### Why the order is not free

Every bond in this machine is permanent. Once a face is attached to the cage,
nothing inside can be touched again — no probe, no rework, no replacement. So the
sequence is determined by one rule: **everything that can be tested must be tested
before the step that makes it unreachable.**

### The sequence

1. **Memory tiers**, tested at wafer, thinned, singulated.
2. **The core stack**: tiers and cooling laminae bonded, thirty-two of each, tested
   as a stack after every few tiers so a bad one is caught before more are added.
3. **The cage** bonded around the core. Tested: this is the last chance to reach
   the core's own interfaces.
4. **Compute dies**, tested at wafer, thinned.
5. **Face assemblies**: dies onto interposers, cold plates bonded on, regulators
   and port fields attached. Tested individually and completely — a face is the
   largest thing that can still be discarded cheaply.
6. **Faces onto the cage**, one at a time. **This is the point of no return** and
   it happens six times.
7. **Edge rails and corner blocks**, sealed.
8. **Pressure test.** The coolant circuit is now closed and this is the only
   opportunity to find a leak before the machine is powered.
9. **The spout's far side**, if `905`'s bonded grade is used. Last, because it
   stakes a second object on the first.
10. **Final test**, from `1204`, through whatever access survives.

### The step that decides everything

**Step six.** Before it, a bad face costs a face. After it, a bad face costs a
cube. So step five's test coverage has to be very close to complete, and `1204` has
to say what fraction it actually reaches — because the difference between
ninety-five and ninety-nine per cent coverage at step five is a large multiple in
the cost of the finished machine.

### The temperature ladder

Each bonding step has a temperature, and every step must be **cooler than the one
before it**, or an earlier bond reflows while a later one is being made. With
hybrid bonds, solder, an elastomer seal and possibly a wafer-level bond at step
nine, the ladder is tight and it is a real constraint. `905`'s bond temperature
against an already-assembled cube is the sharpest case.

## Symbols this must publish

The ordered step list with a test gate on each. Temperature per bonding step.
Value at risk per step. Test coverage required at step five. Point-of-no-return
identification. Rework possibility per step, which is mostly none.

## Constraints this must assert

- Bonding temperatures are monotonically decreasing through the sequence. The
  ladder, asserted, and it is the kind of thing that is obviously required and
  quietly violated when a step is inserted.
- Every step that makes something unreachable is preceded by a test gate covering
  it.
- Step five coverage meets what `1203`'s yield model assumes.
- Step nine's bond temperature is below the lowest temperature anything already
  inside can survive.

## Suggested implementation steps

1. Write the sequence and mark the point of no return.
2. Put a test gate on every step and name what it covers.
3. Build the temperature ladder and check monotonicity.
4. Compute value at risk per step and hand it to `1203`.

## Blocks

`1203`, `1204`, `1205`.

## Blocked by

`205`, `503`, `801`, `905`, `907`, `1201`.

## Related documents

`207` for why there is no repair after this.
