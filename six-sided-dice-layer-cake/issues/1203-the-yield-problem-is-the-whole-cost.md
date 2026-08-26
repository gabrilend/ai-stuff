# 1203 — The yield problem is the whole cost

Produces `src/083-known-good-die.md`.

## Current behavior

Nothing, and `009` entry K1 says so: this is the issue with no number in it yet.

## Intended behavior

**The yield model for a machine assembled from fifty-six separately manufactured
pieces of silicon and about twenty million bonds**, and the redundancy that makes
it survivable.

### Why this dominates everything

Stacking multiplies. Thirty-two memory tiers at ninety-nine per cent each give a
stack yield of seventy-three per cent. At ninety-five per cent each they give
nineteen. **The cost of a cube is not the cost of its silicon; it is the cost of
its silicon divided by the fraction of attempts that work**, and with fifty-six
dice in series that fraction is small unless something is done.

The blueprint should open with the bare multiplication, because it is shocking and
it justifies every mitigation that follows.

### The inventory

| piece | count | notes |
|---|---|---|
| memory tiers | 32 | plus redundant, below |
| cooling laminae | 32 | not silicon, but a bond each |
| compute dies | 24 | four per face |
| face interposers | 6 | large area, mature node |
| cold plates | 6 | large area, coarse features |
| the cage | 1 | large, and irreplaceable |
| radial bonds | 6 × 5.25 M | `702` |
| spout bonds | up to 16.8 M | `902`, only on one face |

### The four mitigations

**Test before committing.** `1202`'s gates. The most valuable of the four and it
costs nothing but time.

**Spare rows and columns** within a tier, from `507`. Turns most tier defects into
non-events.

**A redundant tier.** One of the thirty-two held in reserve. This is what converts
a thirty-two-way series product into something like a thirty-one-of-thirty-two
binomial, and the improvement is large. The blueprint must compute it rather than
assert it, and must say **how many redundant tiers are actually needed** — the
answer may not be one.

**Spare conductors** in the radial and spout arrays, from `702` and `902`. Without
them, cube yield is a function of twenty million independent bonds and is
indistinguishable from zero. The required spare fraction is this blueprint's to
supply and both of those tickets are waiting for it.

### What must come out

A **yield against cost curve**, not a single number. Given a per-die defect
density and a per-bond defect rate, the finished cube yield, and the cost per
working cube. Then the sensitivity: which single improvement buys the most.

The likely answer — and it should be checked rather than assumed — is that the
**bonds dominate**, because there are twenty million of them and only fifty-six
dice, and that the spare fraction in `702` and `902` is therefore the most
important number in phase 12.

## Symbols this must publish

Per-die defect density per node. Per-bond defect rate. Yield per piece. Stack
yield with and without a redundant tier. Required redundant tier count. Required
spare conductor fraction. Finished cube yield. Cost per working cube. Sensitivity
to each mitigation.

## Constraints this must assert

- Finished cube yield exceeds a stated floor at the assumed defect rates.
- Redundant tier count is consistent with the capacity deduction in `501`'s chain.
- Spare fractions handed to `702` and `902` are the ones those blueprints used.
- Test coverage assumed at `1202`'s step five is the coverage `1204` actually
  provides. Three blueprints agreeing about one fraction.

## Suggested implementation steps

1. Do the bare multiplication first and let it be alarming.
2. Build the inventory and get a defect rate for each entry.
3. Model each mitigation and compute the improvement.
4. Find whether dice or bonds dominate, and say so.
5. Produce the sensitivity and name the single best improvement.

## Blocks

`501`, `507`, `702`, `902`, `1302`.

## Blocked by

`503`, `702`, `902`, `1201`, `1202`, `1204`.

## Related documents

`009` entry K1, which this closes.
