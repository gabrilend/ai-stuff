# 081 — Three nodes, not one

```meta
phase  | 12
issues | 1201
```

## Three, and the reason for each

**The compute dies** want the newest node available. Half their area is static
memory whose density sets the slice, and the other half is multipliers whose
switching energy sets the power. Both improve with the node and both are binding.
This is where the money goes.

**The memory tiers** want a node optimised for array density and low leakage
rather than logic speed. `035`'s density assumes a dedicated array tier with the
periphery elsewhere, and the process that gives the best bit cell is not the one
that gives the fastest transistor.

**The interposers, the cage's passive layers and the silicon cold plates** want
nothing modern at all. They are wiring, capacitors and etched channels. An older
node is cheaper, yields better on a large area, and — for the cold plates —
supports the deep etching `022` needs, which a leading-edge line will not do.

## Two things the earlier phases handed here as requirements

**Plasma dicing.** `018` found that tier interfaces carry about a hundred and ten
megapascals once the residual frozen in at bonding is counted, against a sawn
edge's fracture stress of a hundred and fifty — a margin of one point four on a
failure that scraps a whole cube. A plasma-diced edge etches rather than cuts and
leaves no crack population. **It is a requirement, not a preference.**

**A deep etch at high aspect ratio.** `022`'s channels are a hundred and fifty
microns wide and a millimetre deep, which is nearly seven to one in silicon. That
is a real process capability and `C-081-3` checks it rather than assuming it.

## What three processes cost

Three mask sets, three qualifications, three suppliers and three yield curves that
must all be good on the same day for a cube to exist. **The machine's availability
is the intersection of three**, and the blueprint says so plainly rather than
leaving it to be discovered.

## Symbols

```symbols
node_logic    | 1 | given | 3.0     | the compute dies' node, in nanometres as the industry names them
node_array    | 1 | given | 5.0     | the memory tiers' node
node_passive  | 1 | given | 65.0    | interposers, the cage's passive layers and the cold plates
n_maskset     | 1 | given | 3       | mask sets, one per node
ar_etch_max   | 1 | measured | 10.0 | the deepest aspect ratio the chosen passive line etches in silicon
d0_logic      | 1/cm^2 | measured | 0.09 | defect density at the logic node, mature
d0_array      | 1/cm^2 | measured | 0.06 | at the array node
d0_passive    | 1/cm^2 | measured | 0.02 | at the passive node
cost_wafer_l  | 1 | measured | 20000.0 | relative cost of one wafer at the logic node, in arbitrary units so that ratios mean something and prices do not
cost_wafer_a  | 1 | measured | 6000.0  | at the array node
cost_wafer_p  | 1 | measured | 900.0   | at the passive node
A_wafer       | cm^2 | measured | 706.0 | usable area of one three hundred millimetre wafer

n_die_wafer_l | 1 | derived | floor(A_wafer / A_die)                 | compute dies per wafer, before yield
n_tier_wafer  | 1 | derived | floor(A_wafer / A_core_side)           | memory tiers per wafer, before yield
n_plate_wafer | 1 | derived | floor(A_wafer / A_plate)               | cold plates per wafer
n_die_stitch  | 1 | derived | 1                                      | exposures per compute die; one, because 042 sized the die to fit a field
n_tier_stitch | 1 | derived | ceil(A_core_side / A_reticle)          | exposures per memory tier, which is more than one and is what 036 left open
```

## Constraints

```constraints
C-081-1 | node_logic < node_array         | the compute dies use a newer node than the memory tiers, which is the whole reason there are two
C-081-2 | node_array < node_passive       | and the tiers a newer one than the passive layers
C-081-3 | ar_uchan < ar_etch_max          | the microchannel aspect ratio must be inside what the passive line will actually etch. 022 chose the geometry from fin efficiency; this is the only place it is checked against a process that exists
C-081-4 | sigma_si_plas > sigma_si_frac   | the edge finish 018 requires must be the stronger one. Plasma dicing is a requirement handed here by the stress analysis, and asserting it means somebody choosing a cheaper dicing process fails a check rather than shipping cubes that crack
C-081-5 | n_maskset == 3                  | three mask sets. Asserted as a value because a fourth node is a whole supplier and a whole qualification, and it should arrive with an argument
C-081-6 | A_die < A_reticle               | a compute die fits one exposure, which is why its stitch count is one
C-081-7 | n_tier_stitch > 1               | a memory tier does not, which is the question 036 left open, answered: tiers are stitched and compute dies are not
```

## What is still open

**Stitching is named and not designed.** `C-081-7` establishes that a memory tier
takes more than one exposure. How the seam is handled — whether the arrays abut,
whether routing crosses it, what it costs in yield — is not written, and `083`
needs it.

**The cost figures are relative and arbitrary.** They exist so that ratios mean
something in `088` and prices do not, and the blueprint says so. Anybody wanting a
price will have to supply their own three numbers.
