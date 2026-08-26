# 103 — The eleven numbers everything hangs from

Produces `src/012-master-dimensions.md`.

## Current behavior

**Done.** `src/012-master-dimensions.md` exists. Eleven given lengths, sixteen
derived, ten constraints.

The chain from a transformer layer's size to the cube's edge is drawn in the
blueprint as a diagram in symbol names rather than numbers, so `098` checks it.
Two of its rungs -- the layer size and the slice capacity -- name symbols that
phases 6 and 11 will declare, and the diagram checker correctly reports them as
not existing yet.

Seven of the ten constraints hold. Three reach into blueprints that do not exist
yet: the microchannel aspect ratio limit from `022`, the tier count from `036`,
and the seal ring minimum from `017`. The checker reports these separately from
failures, under *not yet*, because a set that is incomplete is a different thing
from one that is wrong.

`C-012-9` -- the two-chain check, where the core's edge derived from outside the
cube must equal the same edge derived from the tier stack -- is written and is
one of the three waiting. It will be the first thing to fire when somebody adds
a tier.

## Intended behavior

**The complete set of lengths in this machine that a person chose.** There are
eleven. Every other length in the project is an expression over these, which means
three things worth having:

- The cube can be resized by editing one file and running `095`, which will report
  which constraint breaks first.
- No blueprint can quietly disagree with another about a dimension, because there
  is only one place a dimension lives.
- A reader who wants to know *what was actually decided*, as opposed to what
  followed, reads one page.

## The eleven

| symbol | mm | what it is | why this value |
|---|---|---|---|
| `L_cube` | 60 | outer edge of the finished cube | falls out of the four below it; see the chain |
| `t_face` | 7.0 | face assembly, outward surface to inward | the stack in `014` adds to just under this |
| `t_cage` | 3.0 | the switch shell lining the cavity | crossbar area, at the wiring pitch of `051` |
| `w_rail` | 4.0 | edge rail width, taken off each face edge | duct area for `024`'s flow at acceptable pressure |
| `L_die` | 24.0 | compute die edge | 576 mm², two thirds of a reticle field |
| `w_street` | 1.0 | gap between dies on a face | placement tolerance plus the seal ring |
| `t_tier_si` | 0.050 | thinned memory tier silicon | as thin as a tier can be handled |
| `t_lamina` | 1.200 | copper cooling plate between tiers | set by the core's heat, `022` |
| `w_uchan` | 0.150 | microchannel width | the hydraulic diameter that gives the coefficient |
| `h_uchan` | 1.000 | microchannel depth | aspect ratio before the fin stops conducting |
| `w_ufin` | 0.150 | copper wall between two microchannels | pressure rating of the plate, `017` |

Eleven numbers. Everything else in ninety blueprints is derived from them, from
`011`'s materials, and from the counts in `010`.

## The chain that produces the cube

This is the part worth reading twice, because it runs in the opposite direction
from the one people expect. The cube is not sixty millimetres because sixty is a
nice number. It is sixty because:

```
   a transformer layer of the reference model      437 MB at four bits
              │
              ▼  prefetch needs two resident (004)
   a face slice must hold                          874 MB
              │
              ▼  at the areal density of 041, half a die
   a compute die must be                           576 mm²  →  24 mm square
              │
              ▼  four of them, two by two, plus a street
   the die block is                                49 mm square
              │
              ▼  plus a seal ring each side
   the face plate is                               52 mm square
              │
              ▼  plus an edge rail each side
   THE CUBE IS                                     60 mm
```

Change the reference model and the cube changes size. That is not a weakness of
the design, it is the design being honest about what determined it, and it is why
`078` treats the model shape as an input rather than an assumption.

## Symbols this must publish

The eleven above as `given`, plus the derived lengths that more than one other
blueprint needs and that therefore belong here rather than in whichever file
happened to want them first:

| symbol | derivation | mm |
|---|---|---|
| `L_cavity` | `L_cube - 2*t_face` | 46 |
| `L_core` | `L_cavity - 2*t_cage` | 40 |
| `L_plate` | `L_cube - 2*w_rail` | 52 |
| `L_dieblock` | `2*L_die + w_street` | 49 |
| `t_tier_pitch` | `t_tier_si + t_lamina` | 1.25 |
| `p_uchan` | `w_uchan + w_ufin` | 0.30 |
| `A_plate` | `L_plate^2` | 2704 mm² |
| `A_die` | `L_die^2` | 576 mm² |
| `V_cube` | `L_cube^3` | 216 cm³ |

## Constraints this must assert

The last of these is the one worth building the whole notation for.

- The die block fits on the face plate with room for a seal ring on each side.
- The face plate fits inside the cube once the edge rails are taken off.
- The cavity is larger than the cage plus the core.
- The microchannel aspect ratio stays under about eight, past which the fin stops
  carrying heat to its own tip and the added depth is wasted copper.
- **The core's edge equals the tier count times the tier pitch.** Thirty-two tiers
  at one and a quarter millimetres is forty millimetres, and forty millimetres is
  what `L_cavity - 2*t_cage` independently produces. Two completely different
  chains of reasoning — one from the outside of the cube inward, one from the
  memory stack outward — have to land on the same number, and this constraint is
  what notices when they stop doing so. It is the single most valuable line in the
  blueprint set.

## Suggested implementation steps

1. Write the eleven, each with its unit, its value, and one line saying who chose
   it and against what.
2. Draw the chain above as a diagram in the blueprint, with symbol names in
   brackets rather than numbers, so `098` can check it.
3. Declare the derived lengths.
4. Write the constraints, and write the two-chain one last and deliberately.
5. Run `095`. Then change `L_die` to 26 and run it again, and confirm that the
   report names the core-edge constraint. A constraint that never fires has not
   been tested.

## Notes on effort

This ticket was a candidate for splitting into two — the given set, and the
derived set with the constraints — and it should not be. The chain from the model
to the cube is one argument and it reads badly cut in half.

## Blocks

Everything from `013` onward.

## Blocked by

`101`, `102`.

## Related documents

`004` walks the same chain from the other end. `078` is the model shape it is
anchored to. `009` entry B4 is the question of whether that anchor is right.
