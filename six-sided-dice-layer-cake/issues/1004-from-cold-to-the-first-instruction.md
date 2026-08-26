# 1004 — From cold to the first instruction

Produces `src/073-reset-and-boot.md`.

## Current behavior

Nothing. `406` sequences the supplies and stops there.

## Intended behavior

**Everything between power being valid and the machine being able to generate a
token**, as an ordered procedure with a time for each step.

### The steps

1. **Supplies valid**, from `406`. Nothing below starts before this.
2. **Reference locked**, from `1001`. Multipliers settle; a stated number of
   microseconds.
3. **Reset released**, in an order: cage first, then faces, so that a face
   releasing early cannot issue into a switch that is not ready.
4. **Memory initialised.** Sixty-four gibibytes of static memory comes up with
   arbitrary contents, and `507`'s error correction over arbitrary contents reports
   errors everywhere. **The core must be written before it is read**, and writing
   sixty-four gibibytes at thirty-nine terabytes a second is about one and three
   quarter milliseconds — which is the longest step here and worth knowing.
5. **Repair applied.** `507`'s spare rows and the redundant tier are mapped in from
   whatever holds the map, which `009` entry M4 says does not exist yet.
6. **Link training**, from `702` and `801`. Deskew per tile, spare remap for failed
   conductors from `902`.
7. **Self test.** `1204`'s reduced set: enough to know the machine is not broken,
   not the full production suite.
8. **Model load.** Thirty milliseconds from `802`.
9. **Descriptor chains built.** `608`'s chains, once, from the header in `803`.
10. **Ready.**

The blueprint must give a time for each and a total, because "how long from power
on to first token" is a question every operator asks and currently has no answer.

### Reset is not one signal

Different blocks need different reset lengths and different release orders, and
some state must survive a reset that other state must not. **The core's contents
should survive a warm reset** — a machine that reloads thirty-five gigabytes
because software restarted is a machine nobody wants. So there are at least two
resets, cold and warm, and the blueprint must say what each clears.

### What happens if a step fails

Each of the ten can fail, and the machine must end up somewhere diagnosable rather
than hung. `609`'s sticky fault bits are the mechanism; this blueprint owns the
requirement that **every step sets a bit on entry and clears it on success**, so
that a machine stopped part way through boot says which step it stopped in. That
one convention is worth more than any amount of later debugging apparatus.

## Symbols this must publish

Step list with duration and dependency. Total cold boot and warm boot time. Reset
tree, depths and release order. What survives a warm reset. Memory initialisation
time. Fault bit per step.

## Constraints this must assert

- Steps are totally ordered and every dependency precedes its dependent.
- Memory initialisation writes every location before anything reads one. The
  constraint that stops `507` reporting a storm of false errors at boot.
- Reset release order matches the supply order in `406`.
- Every step has a distinct fault bit in `609`.
- Warm reset preserves the core, asserted, because it is the property most likely
  to be lost in a later simplification.

## Suggested implementation steps

1. Write the ten steps with times derived from the blueprints that own them.
2. Split cold from warm and say what each clears.
3. Assign a fault bit per step and hand the list to `609`.
4. Total it and publish the number.

## Blocks

`1204`, `1205`.

## Blocked by

`406`, `507`, `608`, `702`, `802`, `902`, `1001`, `1003`.

## Related documents

`085` is the human procedure that wraps this. `009` entry M4 is the gap at step
five.
