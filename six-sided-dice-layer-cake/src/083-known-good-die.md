# 083 — The yield problem is the whole cost

```meta
phase  | 12
issues | 1203
```

## The multiplication that should alarm

**Stacking multiplies.** Twenty-four memory tiers at ninety-nine per cent each
give a stack yield of seventy-nine. At ninety-five per cent each they give
twenty-nine.

**The cost of a cube is not the cost of its silicon; it is the cost of its silicon
divided by the fraction of attempts that work** — and with sixty-one pieces of
silicon and twenty million bonds in series, that fraction is small unless
something is done.

`C-083-1` asserts the bare multiplication in the alarming direction, because a
reader who has not done it will not believe the mitigations are needed.

## Two different yields, kept apart

**Die yield** is what fraction of the dies on a wafer are good. It affects the
*cost per known-good die*, and nothing else — a bad die is discarded before
assembly.

**Assembly yield** is what fraction of assemblies survive being built from
known-good parts. It affects how many finished cubes come out.

Conflating them is the ordinary way to be wrong about this by an order of
magnitude, and the two are derived separately.

## The four mitigations

**Test before committing** (`082`'s gates). The most valuable of the four and it
costs only time.

**Spare rows and columns** within a tier (`040`). Turns most tier defects into
non-events.

**A redundant tier.** One of the twenty-four held in reserve, which converts a
twenty-four-way series product into something like a twenty-three-of-twenty-four
binomial. The improvement is large and it is computed rather than asserted.

**Spare conductors** in the radial and spout arrays (`051`, `063`). Without them,
cube yield is a function of twenty million independent bonds and is
indistinguishable from zero.

## What dominates

The blueprint should find out rather than assume, and it does: **the bonds**.
Sixty-one dice against twenty million bonds is not a close contest, and the spare
fractions in `051` and `063` — both of which are `given` figures those blueprints
asked this one to set — are therefore the most important numbers in the phase.

## Symbols

```symbols
y_bond        | 1 | measured | 0.9999999 | probability one microbump or pillar bond is good
y_bond_hybrid | 1 | measured | 0.99999995 | and one copper-to-copper hybrid bond, which is finer and better controlled
y_handle      | 1 | measured | 0.998    | probability one handling and placement operation does no damage
n_handle      | 1 | given | 40          | handling operations in a whole assembly
f_cover_needed | 1 | derived | 0.98     | test coverage 082's step five must reach for the numbers below to hold
y_floor       | 1 | given | 0.40        | the least finished-cube yield that makes the machine worth building

y_die_logic   | 1 | derived | (1 - exp(-A_die * d0_logic)) / (A_die * d0_logic) | fraction of compute dies good, by the standard model for a mature process
y_die_tier    | 1 | derived | (1 - exp(-A_core_side * d0_array)) / (A_core_side * d0_array) | and of memory tiers
y_die_plate   | 1 | derived | (1 - exp(-A_plate * d0_passive)) / (A_plate * d0_passive) | and of cold plates
n_die_good_l  | 1 | derived | n_die_wafer_l * y_die_logic            | good compute dies per wafer
n_tier_good   | 1 | derived | n_tier_wafer * y_die_tier / n_tier_stitch | good memory tiers per wafer, allowing for stitching

y_stack_naive | 1 | derived | 0.99^n_tier                             | what the tier stack would yield at ninety-nine per cent a tier with no redundancy, which is the alarming number
y_stack_red   | 1 | derived | 0.99^n_tier + n_tier * 0.01 * 0.99^(n_tier - 1) | and with one redundant tier: all good, or exactly one bad
n_bond_radial | 1 | derived | n_radial_pad * n_face                   | bonds in the six radial interfaces
n_bond_all    | 1 | derived | n_bond_radial + n_bond_total + n_tier    | every bond in a cube
y_rad_nospare | 1 | derived | y_bond^n_bond_radial                    | what the radial interfaces would yield with no spares at all
y_rad_spare   | 1 | derived | 1 - n_bond_radial * (1 - y_bond) / n_radial_spare / n_face | roughly, the chance the spares cover the failures; a crude bound rather than a distribution, and marked as such
y_handling    | 1 | derived | y_handle^n_handle                       | surviving forty handling operations
y_cube        | 1 | derived | y_stack_red * y_rad_spare * y_array_spare * y_handling | finished cubes per attempt, from known-good parts
cost_si_cube  | 1 | derived | n_die * cost_wafer_l / n_die_good_l + n_tier * cost_wafer_a / n_tier_good + n_face * cost_wafer_p / (n_plate_wafer * y_die_plate) | silicon in one cube, at known-good prices
cost_cube     | 1 | derived | cost_si_cube / y_cube                   | and per cube that works
f_yield_cost  | 1 | derived | cost_cube / cost_si_cube                | how much of the cost is yield rather than silicon
```

## Constraints

```constraints
C-083-1 | y_stack_naive < 0.85          | twenty-four tiers with no redundancy lose more than one stack in seven at a per-tier yield of ninety-nine per cent. Asserted in the alarming direction, because it is the whole justification for the redundant tier and a reader who has not multiplied it out will not believe one is needed
C-083-2 | y_rad_nospare < 0.5           | and the radial bonds with no spares fail more often than they work. The same argument, three orders of magnitude more forcefully
C-083-3 | y_cube > y_floor              | finished cube yield must clear the floor that makes the machine worth building
C-083-4 | y_stack_red > y_stack_naive   | the redundant tier must help, which is trivially true and catches it being edited to zero
C-083-5 | f_cover_five >= f_cover_needed | 082's face assembly test must reach the coverage this model assumes
C-083-6 | f_yield_cost < 3.0            | yield must not more than triple the cost of the silicon, or the machine is a research object rather than a product
```

## What is still open

**The spare coverage bounds are crude.** Both `y_rad_spare` and `066`'s
`y_array_spare` are one minus expected failures over spares, which is not a
probability. The real question — the chance that failures **cluster** inside one
remap group faster than spares can cover — needs a distribution, and this
blueprint owes `051` and `063` the spare fractions that would come out of it.

**Stitching's yield cost is not modelled.** `081` establishes that memory tiers
take more than one exposure and nothing here charges for the seam.

**Handling is one number for forty operations.** Two tenths of a per cent each is
plausible and undifferentiated: bonding a fifty millimetre array is not the same
risk as placing a die.
