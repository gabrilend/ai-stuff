# 301 — How much heat, and from where

Produces `src/020-heat-budget.md`.

## Current behavior

Nothing. Nineteen hundred and ten watts is used everywhere and derived nowhere.

## Intended behavior

**Every watt in the machine, attributed to a mechanism rather than to a
component**, so that the budget moves when the design does instead of being
re-entered by hand.

The distinction matters. "The compute dies dissipate thirteen hundred and eighty
watts" is a number somebody typed. "Each of the twenty-four dies dissipates the
switching energy of its matrix engine at its utilisation, plus its leakage at its
temperature, plus its slice's read energy at its access rate" is a number that
changes correctly when the clock, the batch size or the die area changes.

### The mechanisms

| mechanism | where | scales with |
|---|---|---|
| matrix engine switching | 24 dies | clock × utilisation × array area |
| scalar and sequencer logic | 24 dies | clock |
| face slice read energy | 24 dies | bytes read per second × pJ/bit |
| logic leakage | 24 dies | area × temperature |
| core array read energy | 32 tiers | 39 TB/s × pJ/bit |
| core leakage | 32 tiers | bit count × temperature |
| radial link | 6 links | bits crossed × pJ/bit |
| crossbar | the cage | bits switched |
| port fields | 6 | line rate, mostly idle |
| the spout | 1 | burst; see below |
| **conversion loss** | 6 interposers | everything above, divided by efficiency |

**Leakage depends on temperature and temperature depends on leakage.** This is a
loop and the blueprint has to close it by iteration rather than by picking one
value. It matters: silicon leakage roughly doubles every ten kelvin, so a design
that assumes twenty-five degrees and runs at sixty-five is out by a factor of
sixteen on that term. The blueprint should iterate to a fixed point and state how
many iterations it took, because if it takes many the design is near thermal
runaway and somebody should know.

**The spout is an energy budget, not a power budget.** A pane costs a hundred and
sixty-eight nanojoules and a full core copy five and a half millijoules over
thirty-three microseconds — a hundred and sixty-eight watts while it runs, which is
nine per cent of the machine's total, arriving and leaving faster than the silicon
can warm up. It belongs in `026`'s transient analysis and in this budget only as a
duty-cycled average.

### The three operating points

One number is not enough. The budget must be produced at three points because they
stress different parts of the machine:

- **Idle.** Model resident, nothing generating. Leakage plus refresh plus clocks.
  This is what sets the machine's floor and it is not small: sixty-four gibibytes
  of static memory leaks whether or not anyone is asking it anything.
- **Single stream decode.** One face working, five idle, memory saturated. Lowest
  compute power, full memory power.
- **Batch decode at the crossover.** All six faces working, memory saturated. The
  design point, and the largest number.

## Symbols this must publish

A watt figure per mechanism per operating point, the three totals, the conversion
losses, the input power, and the per-face and per-die breakdown that `022` needs
to size the fields. Also the fixed-point iteration count for leakage.

## Constraints this must assert

- **Input power equals total heat, exactly.** The one energy statement in the
  project that cannot be approximately true. `095` should treat a failure here as
  a structural error rather than a design one.
- The design point total stays under what `022`'s fields can remove at the allowed
  junction temperature.
- Per-die power stays under what the hot spot analysis in `025` permits.
- The leakage iteration converges — successive values differ by under a per cent —
  and the blueprint fails rather than reporting a number if it does not.

## Suggested implementation steps

1. Write the mechanism table with a derivation for each, in symbols.
2. Get the picojoules-per-bit figures from `035`, `047` and `051` rather than
   assuming them.
3. Close the leakage loop by iteration and report the count.
4. Produce all three operating points.
5. Assert the energy equality and watch it fail the first time, because it always
   does, and the thing it catches is a mechanism counted twice.

## Blocks

`302`, `303`, `305`, `306`, `307`, `401`.

## Blocked by

`102`, `605` for the engine's switching energy, `502` for the array's read energy,
`702` for the link's.

## Related documents

`005` for where it all goes. `006` for the conversion losses.
