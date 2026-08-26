# 306 — Junction to room, every term

Produces `src/025-thermal-resistance-network.md`.

## Current behavior

`005` draws the chain with numbers beside it. None of them is derived and one of
them — the largest — is a guess.

## Intended behavior

**The complete thermal resistance network from a transistor junction to the air in
the room, every term derived from a geometry and a material property, with the
worst case rather than the average at every step.**

### The chain

| term | mechanism | ~K |
|---|---|---|
| junction to die back | spreading from a hot region into the bulk | **~15** |
| die bulk | one-dimensional conduction, 100 µm | 0.03 |
| die-to-plate bond | copper–copper hybrid | ~0 |
| cold plate base | conduction, 300 µm silicon | 0.27 |
| plate to fluid | convection, from `022` | 1.8 |
| fluid through the cube | sensible heating, from `024` | 7.8 |
| the external loop | from `027` | ~12 |

### The term that matters

**Spreading resistance dominates by a factor of eight and is currently a guess.**
This is the most important sentence in phase 3.

Heat is not generated uniformly across a die. A matrix engine running flat out
concentrates it into the multiplier array, which may be a third of the die area
producing three quarters of the power. Getting that heat out means spreading it
sideways through a hundred microns of silicon at a hundred and thirty watts per
metre per kelvin, and the resistance of that spread depends on the ratio of the
hot region's size to the cooled area, not on the die's average flux.

The blueprint must:

- take the actual power map from `601`'s floorplan rather than assuming uniformity
- use a spreading resistance formulation valid for the source-to-sink ratio here,
  and say which one and over what range it is valid
- report the **peak junction temperature**, which is what the silicon cares about,
  not the mean

**If this term comes out at forty kelvin rather than fifteen, the machine's sixty
kelvin of margin is gone and the clock in `1005` comes down.** `009` entry T1
carries it and it should be the first thing resolved once `605` has a floorplan.

### Worst case, everywhere

Every term takes its worst value simultaneously: the worst-served field from
`305`, the hottest point in the coolant path (the last face before an outlet
corner), the highest-power die, the hottest region on it. This is pessimistic and
correct. A thermal design validated at the mean is a thermal design that fails on
one part in six.

## Symbols this must publish

Every resistance in kelvin per watt, every temperature rise in kelvin, junction
temperature at each of `301`'s three operating points, the margin to the limit,
and the sensitivity of junction temperature to each term — so a reader can see at
a glance which number to go and improve.

## Constraints this must assert

- Peak junction temperature at the design operating point stays under the silicon
  limit from `011`, with a stated margin.
- The sum of the derived terms agrees with junction temperature minus room
  temperature. Trivial, and it catches a term left out.
- Every term is derived, not entered. A `target` kind anywhere in this blueprint
  is a failure of the blueprint, and the spreading term is currently exactly that
  — which `104` should be reporting loudly until `605` lands.

## Suggested implementation steps

1. Build the chain as a series network with each resistance derived.
2. Do the spreading term properly with a real power map, or, until `601` exists,
   carry it as a `target` and let the checker complain.
3. Take worst case at every step and say so.
4. Produce a sensitivity table.
5. Report junction temperature at all three operating points.

## Blocks

`307`, `1005`, `1206`.

## Blocked by

`301`, `303`, `305`, `601`, `605`.

## Related documents

`005` is this chain as a story. `009` entry T1 is the open question inside it.
