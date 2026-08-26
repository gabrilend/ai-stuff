# 601 — The plan of one die

Produces `src/041-face-floorplan.md`.

## Current behavior

Nothing, and `306` is blocked on it: the largest term in the whole thermal chain
is a spreading resistance that cannot be computed without a power map.

## Intended behavior

**Where everything sits on a twenty-four millimetre square die, and how much power
each region makes.** The floorplan is a thermal document as much as a layout one,
and this ticket exists mostly to produce the power map `306` needs.

### The budget of area

| block | mm² | share |
|---|---|---|
| face cache slice, static memory | 288 | 50 % |
| matrix engine array | ~60 | 10 % |
| accumulators, operand staging, weight expansion | ~50 | 9 % |
| sequencer | ~15 | 3 % |
| scalar core | ~8 | 1 % |
| radial link termination and interface | ~40 | 7 % |
| power grid, decoupling access, clock | ~60 | 10 % |
| margin and routing | ~55 | 10 % |

**Half the die is memory**, and it is half because a transformer layer of the
reference model is four hundred and thirty-seven megabytes and the prefetch in
`805` needs two of them resident. That number came from `004` and it is what makes
the die twenty-four millimetres, which makes the cube sixty. The floorplan is
downstream of an arithmetic fact about language models.

### The thermal problem, which is the real content

The matrix engine is ten per cent of the die and makes about seventy per cent of
its heat. Forty watts in sixty square millimetres is two thirds of a watt per
square millimetre, against a die average of a tenth.

The cold plate is bonded to the whole back of the die, so the heat does not have
to travel far — it goes straight up through a hundred microns of silicon into the
channels directly above. That is a fifth of a kelvin and it is not the problem.

**The problem is that only the channels directly above the engine are available to
it.** Ten per cent of the plate's wetted area has to remove seventy per cent of
the heat. Locally that is about ten kelvin of convection rise instead of the
face-average one and four fifths, and it is where `005`'s fifteen kelvin hot spot
term comes from.

### Three mitigations, and the blueprint must price all three

**Checkerboard the engine into the slice.** Break the array into tiles and
interleave them with memory tiles so that no hot tile touches another. Lateral
conduction over a millimetre in a hundred micron die is not free — about eight
kelvin per tenth of a watt over a one millimetre strip — but the memory tiles
between are nearly cold and give somewhere for it to go.

**Spread the array over more area.** Lower the multiplier density and use more of
the die. Costs area that the slice wants, and the slice cannot give any.

**Accept it.** Fifteen kelvin against sixty of margin is affordable today. It stops
being affordable the moment `009` entry T1 resolves upward, or the clock rises, or
the coolant inlet is allowed to be warm so the radiator can be smaller.

The blueprint must produce the power map at a resolution fine enough for `306` to
do a real spreading calculation, and must present the checkerboard as a layout
rather than as an intention.

## Symbols this must publish

Area per block. Power per block at each of `301`'s operating points. Power density
per block. The power map as a grid coarse enough to write down and fine enough to
integrate. Local wetted area available to each block. Local convection rise per
block. Peak on-die temperature.

## Constraints this must assert

- Block areas sum to the die area from `012`.
- Slice area times areal density from `607` gives a capacity of at least twice a
  layer's weights from `1104`.
- Block powers sum to the per-die power in `301`.
- Peak local convection rise, taken over the power map, stays inside the allowance
  in `306`.
- No two engine tiles are adjacent, checked over the checkerboard layout.

## Suggested implementation steps

1. Allocate area, starting from the slice, because it is the constrained one.
2. Draw the checkerboard.
3. Produce the power map as data, not as a picture, so `306` can integrate it.
4. Compute local wetted area and local rise per block.
5. Price the three mitigations and record the choice in `docs/balance-updates.md`.

## Blocks

`306`, `602`, `605`, `607`, `1201`.

## Blocked by

`103`, `202`, `301`, `605` for the engine's area, `607` for the slice's density.

## Related documents

`005` for the chain this feeds. `009` entry T1.
