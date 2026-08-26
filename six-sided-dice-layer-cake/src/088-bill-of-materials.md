# 088 — What it is made from, and what that costs

```meta
phase  | 13
issues | 1302
```

## The rule

**No quantity in this document is entered by hand.** A count comes from a
blueprint's symbols; a mass from a volume times a density; an area from a
dimension squared. `097` produces the document from the ledger, and the only
hand-written things are supplier names and cost figures, which are `measured`
with a source.

A bill of materials typed once is wrong within a month, and this is the document
somebody will use to decide whether the machine can exist.

## What dominates

Not the parts list. **Which three things dominate**, ranked:

**Silicon area, weighted by node.** Sixty-one pieces, and the compute dies are on
the newest process available.

**Yield**, from `083`. Cost per working cube is cost per attempt divided by yield,
and with sixty-one pieces and twenty million bonds in series the divisor is where
the money goes.

**The bonding steps.** Twenty million connections made in a handful of operations
on objects that are already nearly finished.

Everything else — the stainless, the pump, the seal — is noise beside those three,
and saying so is what stops somebody optimising the wrong thing.

## What it deliberately does not do

**Give a price.** There is no volume, no supplier and no year, so a number would
be fiction. What it gives instead is the **structure** of the cost and the
sensitivity to each driver, which stays true when prices do not.

## Symbols

```symbols
n_part_cube   | 1 | given | 61       | pieces of silicon in one cube
n_part_loop   | 1 | given | 9        | components in the external loop: two pumps, radiator, fan, reservoir, filter, couplings, tubing, sensors
n_consumable  | 1 | given | 2        | consumables: the fluid and the filter element
cost_assy     | 1 | measured | 3000.0 | relative cost of the assembly operations in 082, in the same arbitrary units as the wafers

m_si_cube     | kg | derived | (n_die * A_die * t_die + n_tier * A_core_side * t_tier_si + n_face * A_plate * t_coldplate * f_solid_plate) * rho_si | silicon in one cube by mass
A_si_logic    | mm^2 | derived | n_die * A_die                    | silicon at the logic node
A_si_array    | mm^2 | derived | n_tier * A_core_side             | at the array node
A_si_passive  | mm^2 | derived | n_face * (A_plate + A_plate)     | at the passive node: the cold plates and the interposers
A_si_total    | mm^2 | derived | A_si_logic + A_si_array + A_si_passive | all of it
n_bond_cube   | 1 | derived | n_bond_all                          | bonds in one cube
cost_total    | 1 | derived | cost_cube + cost_assy               | one working cube, silicon and assembly, in arbitrary units
f_cost_si     | 1 | derived | cost_si_cube / cost_total           | the share that is silicon at known-good prices
f_cost_yield  | 1 | derived | (cost_cube - cost_si_cube) / cost_total | the share that is yield
f_cost_assy   | 1 | derived | cost_assy / cost_total              | and the share that is assembly
m_total_wet   | kg | derived | m_cube                              | the finished object, from 013
V_consume_yr  | mm^3 | derived | V_leak_life + V_spill_life        | fluid consumed in a year of service
```

## Constraints

```constraints
C-088-1 | f_cost_si + f_cost_yield + f_cost_assy ~= 1 | the three cost shares must be the whole cost, with nothing unattributed
C-088-2 | m_si_cube < m_total_wet     | the silicon must be a small part of the mass, which it is by a wide margin and which is the surprising fact about this object: it is mostly a molybdenum heat exchanger
C-088-3 | A_si_logic < A_si_array     | there is more array silicon than logic silicon, which is what a machine built around a block of memory should look like
C-088-4 | f_cost_yield > 0.02         | yield must stay a visible share of the cost, so that nobody removes a mitigation on the grounds that it is not costing anything. It comes out near a twelfth, which is the finding: with test gates, spare rows, a redundant tier and spare conductors in place, assembly yield stops being what this machine costs. What it costs instead is memory tiers -- a third of them are scrapped at wafer, and the array node is two thirds of the silicon bill
C-088-5 | n_bond_cube > n_part_cube * 1000 | there are orders of magnitude more bonds than parts, which is why 083 found the bonds dominate and is the fact a parts list would otherwise hide
C-088-6 | V_consume_yr < V_reservoir  | a year's consumption must fit in the reservoir, which is what makes the service interval a year
```

## What is still open

**The cost figures are relative.** They exist so ratios mean something and prices
do not, and anybody wanting a price must supply three wafer costs and an assembly
cost of their own. The **structure** — that yield is a fifth or more of it, and
that the bonds are why — is what survives.

**The translation unit is not costed.** `069a` is a separate object with a
separate lifetime and it is not in this list, which is correct and is also the
reason a machine's total cost is not this number.
