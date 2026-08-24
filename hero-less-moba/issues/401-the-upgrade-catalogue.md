# 401 — The Upgrade Catalogue

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 201 |
| Blocks | 402, 403, 405, 408, 605 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | B7 |

## Current behavior

Upgrades are a word in the vision. Nothing exists.

## Intended behavior

A **catalogue** of upgrade kinds, fixed at build time, living in a table under
`assets/`. One row per kind:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Row number. |
| `name` | string | Shown to players. |
| `weight` | integer | Relative likelihood of being drawn. |
| `bit` | integer | Which bit this kind occupies in a soldier's `upgrade_mask`. |
| `applies_to` | integer | Bit set: 1 wave units, 2 towers. No hero bit exists. |
| `add` | double[] | Flat additions, one per modifiable stat. |
| `mul` | double[] | Multipliers, one per modifiable stat. |
| `behaviour` | integer | Row in a behaviour dispatch table, or **0** for a pure stat change. |

The modifiable stats are the soldier fields worth touching: damage, armour,
health, range, speed, attack cooldown. Anything that is not a number — a splash
on hit, a death rattle, a shield on the front rank — is a **behaviour**, an entry
in a dispatch table, so that adding one is adding a row rather than editing the
combat loop.

The `bit` field is what makes a soldier's upgrade set a single integer. That
integer is stamped once at spawn and read on every swing, so the catalogue's size
is bounded by the width of that integer. If more kinds are wanted than bits
available, that is a real design decision — a second mask word, or a smaller
catalogue — and it should be made deliberately rather than discovered.

Not every kind can go into stone. `applies_to` says which destinations a kind
accepts, and a placement into a slot the kind does not accept is refused with a
reason. Speed and health on an immobile building are meaningless; damage, range,
and rate of fire are not.

## Suggested implementation steps

1. Write the catalogue as a data table under `assets/`, not as code. It is data,
   it will be edited constantly, and it should be diffable.
2. Write the loader and a **catalogue validator**: every kind has a distinct bit,
   every weight is positive, every `applies_to` is nonzero, every behaviour index
   resolves. A validator failure stops the program and names the row.
3. Write the behaviour dispatch table with a small number of real entries — a
   splash, a death rattle, a front-rank shield — so the mechanism is exercised
   rather than theoretical.
4. Write the mask-application routine: given a mask and a stat, return the
   modified value, additive terms before multiplicative.
5. Write the balance validator hook that reports the catalogue's contents, so no
   document ever has to quote a number from it.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)
- The catalogue validator (this issue creates it)

## Settled

**Upgrades never apply to hero units.** No hero bit, no per-kind exception, no way
to write one — enforce it in the **structure** of the catalogue rather than by
everybody remembering: `applies_to` is two bits, the validator refuses anything
outside {1, 2, 3}, and the mask-stamping routine returns zero for any flavour
that is not a wave unit. A rule that can only be broken by editing the validator
will not be broken by accident.

Why the two economies must not multiply is in
[the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md).

## Still open

**How many kinds should exist, and what are the weights?** The `bit` field means
the catalogue's size is bounded by the width of the integer holding a soldier's
mask. If more kinds are wanted than bits available, that is a real decision — a
second mask word, or a smaller catalogue — and it should be made deliberately
rather than discovered when the thirty-third upgrade silently does nothing.
