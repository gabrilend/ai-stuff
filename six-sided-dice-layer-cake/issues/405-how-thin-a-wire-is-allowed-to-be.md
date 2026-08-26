# 405 — How thin a wire is allowed to be

Produces `src/032-current-density-and-electromigration.md`.

## Current behavior

Nothing. One milliampere per square micron has been quoted once and sourced
nowhere.

## Intended behavior

**The minimum cross-section of every conductor in the machine, derived from the
current it carries and the life it must have.**

### The mechanism, because the number is meaningless without it

Electrons crossing a metal conductor collide with its atoms and push them
downstream. At low current density the metal's own diffusion repairs the damage.
Above a threshold it does not, and material accumulates at one end of a conductor
and is depleted at the other until a void opens the line or a hillock shorts it to
its neighbour.

The rate depends on current density and, much more strongly, on temperature — it
goes as an exponential in the reciprocal of absolute temperature, so a conductor
qualified at eighty-five degrees is not qualified at a hundred and five. **The
limit must be stated at the operating temperature from `306`, not at a datasheet
temperature**, and this is the mistake the blueprint exists to prevent.

### Where it binds

| conductor | current | why it is a candidate |
|---|---|---|
| regulator output to microbump | 307 A per face | the largest current in the machine |
| via island feedthrough | 6.6 A per face over sixteen islands | smallest cross-section carrying real current |
| microbump to a die | 76.7 A over the pad array | per-pad current is the question |
| radial pillar array | 51 A inward per face | shares pads with signal, so the split matters |
| die power grid upper metal | local | classic case; standard rules apply |

The blueprint should identify the binding case rather than treating all five
equally. **It is expected to be the via islands**, because `202` sized them for
conductor count and `403` then asked them to carry every ampere entering a face
through sixteen small holes — in a plate full of water, at the highest local
temperature in the power path.

### The two failure modes are not the same

An **open** is benign in the sense that the machine stops. A **hillock short**
between a power conductor and a signal conductor is not, because the machine keeps
running and produces wrong answers. Spacing rules matter as much as width rules
and are more often forgotten.

## Symbols this must publish

Allowed current density per metal type at the operating temperature, with the
source and the temperature named. Required cross-section per conductor. Actual
cross-section per conductor. Margin per conductor. Spacing rules. Projected
lifetime at the design current, compared against `1206`'s target.

## Constraints this must assert

- Every conductor's actual cross-section exceeds its required one, with margin.
- Projected lifetime at the worst conductor exceeds the target in `1206`.
- Conductor spacing exceeds the hillock rule everywhere a power net runs beside a
  signal net.
- The current density limit is quoted at a temperature that matches `306`'s
  worst-case junction temperature. A cross-check between two blueprints that would
  otherwise never meet.

## Suggested implementation steps

1. Get the limit at temperature, with a source, into `011`.
2. Enumerate the candidate conductors with their currents from `401`.
3. Compute required against actual and find the binding case.
4. If it is the via islands, hand the result back to `202` and `403` rather than
   widening the rule.
5. Write the spacing rules and say which failure mode each prevents.

## Blocks

`1206`, `1301`.

## Blocked by

`102`, `306`, `401`, `403`.

## Related documents

`006`. `086` for the life this is measured against.
