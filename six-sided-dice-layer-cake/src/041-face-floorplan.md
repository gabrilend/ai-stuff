# 041 — The plan of one die

```meta
phase  | 6
issues | 601
```

Where everything sits on a twenty-four millimetre square, and how much power each
region makes. **This is a thermal document as much as a layout one**: `025`'s
largest term has been waiting on the power map it produces.

```drawing
one compute die, the checkerboard [not-dimensioned]

   ┌───────────────────────────────────────┐
   │  ▓   ▓   ▓   ▓   ▓   ▓   ▓   ▓        │   ▓  one engine tile,
   │                                       │      [L_tile] across
   │  ▓   ▓   ▓   ▓   ▓   ▓   ▓   ▓        │      on a pitch of
   │                                       │      [p_tile]
   │  ▓   ▓   ▓   ▓   ▓   ▓   ▓   ▓        │
   │                                       │   everything between them
   │  ▓   ▓   ▓   ▓   ▓   ▓   ▓   ▓        │   is slice: static memory,
   │                                       │   nearly cold, and somewhere
   ├───────────────────────────────────────┤   for the heat to go
   │  sequencer │ scalar │ link termination │
   └───────────────────────────────────────┘

   the array is a tenth of the die, so it is scattered through the
   memory rather than alternating with it
```

## The area budget

Half the die is memory, and it is half because a transformer layer of the
reference model is a certain size and `060`'s prefetch needs two of them
resident. That number came from a fact about language models, and it is what
makes the die twenty-four millimetres, which makes the cube sixty. **The
floorplan is downstream of arithmetic about transformers.**

## The thermal problem, which is the real content

The multiplier array is about a tenth of the die and makes about seventy per cent
of its heat. The heat does not have far to go — the cold plate covers the whole
back and the channels are directly above — so getting out vertically is a fifth
of a kelvin.

**The problem is that only the channels directly above the engine are available
to it.** A tenth of the wetted area removing seventy per cent of the heat is about
twelve kelvin locally against the face's two.

**Scattering the array into tiles was expected to help by letting heat spread
sideways into the cold memory around each one. It does not.** A hundred micron
die is a poor lateral conductor: moving one tile's share of the heat two
millimetres sideways through it costs over a hundred kelvin, which is more than
ten times the local convection excess it was supposed to relieve. `C-041-5`
records that in the failing direction rather than deleting it, because the
expectation is a reasonable one and somebody will have it again.

What the scattering does buy is two other things, both real.

**The coolant picks the heat up evenly along its path.** Sixty-four small sources
spread across the plate warm every channel run a little, where one large source
would put the whole engine's load on the twenty channels above it and leave those
channels' outlet end far hotter than the rest.

**Power delivery becomes possible.** Sixty amperes into one sixty square
millimetre block needs a local grid density that `030`'s numbers do not reach.
Sixty-four tiles of under a square millimetre each is the same current spread
over the whole die, which is what the grid in `030` was sized for.

The local convection excess itself is unchanged by scattering, and `025` already
accounts for it. The remedy for *that* is to vary the channel density across the
cold plate to match the power map — finer channels above the engine tiles — which
is manufacturable, is not in `022`, and is the best unexplored idea in the
thermal design.

## Symbols

```symbols
f_area_slice   | 1 | given | 0.50  | share of a compute die given to its cache slice
f_area_engine  | 1 | given | 0.104 | share given to the multiplier array and its accumulators
f_area_expand  | 1 | given | 0.087 | share given to operand staging and the weight expansion path
f_area_seq     | 1 | given | 0.026 | share given to the sequencer
f_area_scalar  | 1 | given | 0.014 | share given to the scalar core
f_area_link    | 1 | given | 0.069 | share given to the radial link termination on this die
f_area_pwr     | 1 | given | 0.104 | share given to the power grid, clock and decoupling access
f_area_margin  | 1 | given | 0.096 | routing and margin
n_tile_engine  | 1 | given | 64    | tiles the multiplier array is broken into and scattered across the die
L_tile_min     | mm | given | 0.5  | the smallest an engine tile may be before its own boundary costs more in routing than the spreading it buys
util_design    | 1 | given | 1.0   | multiplier utilisation at the design operating point, which is the crossover batch where the engines are the wall

f_area_sum     | 1    | derived | f_area_slice + f_area_engine + f_area_expand + f_area_seq + f_area_scalar + f_area_link + f_area_pwr + f_area_margin | everything on the die, which must be everything
A_slice_die    | mm^2 | derived | f_area_slice * A_die     | area one die's slice occupies
A_engine_die   | mm^2 | derived | f_area_engine * A_die    | area its multiplier array occupies
L_tile         | mm   | derived | sqrt(A_engine_die / n_tile_engine) | edge of one engine tile
p_tile         | mm   | derived | L_die / sqrt(n_tile_engine)        | spacing between engine tiles, which is how far heat travels to reach cold memory
f_engine_power | 1    | derived | P_engine_die / P_die     | share of a die's heat the array makes, which 025's local term needs
f_engine_area  | 1    | derived | f_area_engine            | and the share of its area, under the name 025 uses
dT_lateral     | K    | derived | f_engine_power * P_die / n_tile_engine * (p_tile - L_tile) / (k_si * L_tile * t_die) | temperature drop for heat crossing the gap from one engine tile into the memory around it, which is what the scattering buys and what limits how much it buys
```

## Constraints

```constraints
C-041-1 | f_area_sum ~= 1                        | the blocks must account for the whole die. Written as an exact agreement because area left over is area nobody drew
C-041-2 | C_face_slice >= 2 * C_layer_weights    | the slice must hold the layer being computed and the layer being fetched. The tightest constraint in the project, and the one that made the die twenty-four millimetres
C-041-3 | n_tile_engine * L_tile^2 ~= A_engine_die | the engine tiles must account for the whole array's area. Written first as though the checkerboard were half engine and half memory, which it is not: the array is a tenth of the die, so it is scattered through the memory rather than alternating with it
C-041-4 | f_engine_power > f_engine_area         | the array makes a larger share of the heat than it takes of the area. This is the whole hot spot problem stated as a single inequality, and it is asserted in the direction of alarm because it will always be true and its magnitude is what matters
C-041-5 | dT_lateral > dT_hotspot                | asserted in the failing direction, deliberately: spreading heat sideways through a hundred micron die costs an order of magnitude more than the local convection excess it was meant to relieve, so lateral conduction is not why the array is scattered. Keeping this as a constraint records a reasonable expectation that turned out to be wrong, rather than quietly deleting it
C-041-6 | L_tile > L_tile_min                    | a tile must be large enough that its own boundary costs less in routing than the spreading is worth
C-041-7 | p_tile > L_tile                        | there must be memory between two engine tiles, which is the whole of what scattering means
```

## What is still open

**The checkerboard is a layout and not a simulation.** Its benefit is estimated
from one-dimensional lateral conduction across a tile, which is pessimistic in
one direction — real spreading is two-dimensional — and optimistic in another,
since it ignores that a memory tile with an engine on four sides is not cold.

**Three mitigations were named and only one was taken.** Spreading the array over
more area costs slice area the slice cannot give. Accepting the hot spot is what
the twenty kelvin of margin in `025` currently pays for, and that margin is what
`027` wants to spend on removing a chiller. **Those two cannot both have it**, and
nothing has decided which.

**The power map is a set of fractions, not a map.** `025` integrates it as though
the engine's heat were uniform over the engine's area, which the checkerboard
makes truer than it was and does not make true.
