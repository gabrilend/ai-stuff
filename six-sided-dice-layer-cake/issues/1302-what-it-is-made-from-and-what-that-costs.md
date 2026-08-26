# 1302 — What it is made from, and what that costs

Produces `src/088-bill-of-materials.md`.

## Current behavior

Nothing. Nobody has counted the parts.

## Intended behavior

**Every part in a cube and in the loop around it, with a count, a material, a
process and a cost driver** — generated from the geometry rather than typed.

### The rule

**No quantity in this document is entered by hand.** A count comes from a
blueprint's symbols; a mass comes from a volume times a density; an area comes
from a dimension squared. `097` produces the document from the ledger, and the
only hand-written things in it are the supplier names and the cost figures, which
are `measured` with a source and a date.

The reason is the usual one. A bill of materials typed once is wrong within a
month, and this is the document somebody will use to decide whether the machine
can exist.

### The structure

**Inside the cube.** Silicon by type and area. Copper-molybdenum laminae. Stainless
rails and corner blocks. Interposers. Elastomer seal. Connectors. Bonds, counted,
because at twenty million they are a line item.

**The loop.** Pump and its redundant partner, radiator, fan, reservoir, filter,
couplings, tubing, sensors, the interlock.

**The translation unit**, from `909`, listed separately because it is a different
object with a different lifetime.

**Consumables.** Coolant, filter elements, and their service interval from `308`.

### The cost drivers, which are the useful part

A parts list is not interesting. What somebody needs is **which three things
dominate**, and the blueprint should rank them:

- **Silicon area**, weighted by node. Fifty-six dice, and the compute dies are on
  the newest process available.
- **Yield**, from `1203`. Cost per working cube is cost per attempt divided by
  yield, and with fifty-six dice in series the divisor may exceed the dividend's
  variation.
- **The bonding steps.** Twenty million connections made in a handful of
  operations on objects that are already nearly finished.

Everything else — the stainless, the pump, the seal — is noise beside those three,
and the blueprint should say so plainly so that nobody optimises the wrong thing.

### What it deliberately does not do

Give a price. There is no volume, no supplier and no year, so a number would be
fiction. What it gives instead is the **structure** of the cost and the sensitivity
to each driver, which stays true when prices do not.

## Symbols this must publish

Part count by category. Silicon area by node. Bond count by type. Mass by
material. Loop component list. Consumable list with intervals. Cost driver ranking
with sensitivities. Total part count.

## Constraints this must assert

- Mass summed here equals `013`'s derived mass. Two routes.
- Silicon area summed here equals what `1203`'s yield model used.
- Bond count summed here equals `051` plus `063` plus the assembly bonds in `082`.
- Every quantity has a derivation, none is a literal. Checked by `095` refusing a
  `given` in this file.

## Suggested implementation steps

1. Write it as a generator specification, not as a list.
2. Pull every count from the ledger.
3. Rank the cost drivers and give sensitivities.
4. Refuse to give a price and say why.

## Blocks

`1303`, `1304`.

## Blocked by

`013`, `1201`, `1202`, `1203`, `308`, `909`.

## Related documents

`001` for what the deliverable is.
