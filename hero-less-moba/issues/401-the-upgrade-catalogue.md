# 401 — The Upgrade Catalogue

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 201 |
| Blocks | 402, 403, 405, 408, 605 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | B7 |

## Current behavior

Eight kinds, each with a colour, a glyph, additive and multiplicative terms, a
reach that decides which half of a wave it touches, and what it does to stone. A body
carries a small integer per kind rather than a bit set, because duplicates stack and a
bit set cannot count.

One kind has an empty tower effect on purpose: stone does not walk, so Boots in a lane
is a push and Boots in stone is a wasted slot.

## Intended behavior

A **catalogue** of upgrade kinds, fixed at build time, living in a table under
`assets/`. One row per kind:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Row number. |
| `name` | string | Shown to players. |
| `weight` | integer | Relative likelihood of being drawn. |
| `bit` | integer | Which bit this kind occupies in a soldier's `upgrade_mask`. |
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

**Every kind can go into every slot, and nothing is ever refused for being the
wrong kind.** *Settled; see [open questions](../docs/020-open-questions.md), F28.*

There is one catalogue and no audience field on it. An upgrade modifies stats,
and a body benefits to the extent that it has those stats and uses them. The
three things upgrades reach — **wave units, guards, and towers** — overlap almost
completely: they all have health, three of the four have feet, two swing and two
throw. A guard and a tower are opposites with everything in common.

So a movement upgrade slotted into a lane's towers is not refused and is not
wasted: it does nothing for the tower, which is stone, and makes its guards cover
their ground faster, which is a real purchase. **The routing falls out of the
numbers and does not need a field.**

An earlier draft of this issue built two fields for this — `applies_to` and
`shape` — and a validator that refused anything outside their ranges. Both are
gone. A tag is a second description of a thing that already describes itself, and
the two can disagree the first time somebody writes an upgrade that adds both
movement speed and ranged damage.

**The one audience rule that remains is not in the catalogue.** Heroes are
excluded by **flavour**, in the mask-stamping routine, so it is one check in one
place rather than a field that has to be set right on every row.

## Suggested implementation steps

1. Write the catalogue as a data table under `assets/`, not as code. It is data,
   it will be edited constantly, and it should be diffable.
2. Write the loader and a **catalogue validator**: every kind has a distinct
   index into the count vector, every weight is positive, every behaviour index
   resolves, and **every kind touches at least one stat** — a row that modifies
   nothing is a typo, not an upgrade. A validator failure stops the program and
   names the row.
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

**Upgrades never apply to hero units.** No per-kind exception and no way to write
one. Since the catalogue carries no audience field at all (F28), this is enforced
in exactly one place: **the stamping routine returns an empty vector for any
flavour that is not a wave unit or a guard.** One check, one file, one comment
saying why — which is a stronger guarantee than a field on every row that
somebody has to remember to set, and a much easier one to find.

Why the two economies must not multiply is in
[the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md).

## Still open

**How many kinds should exist, and what are the weights?** The `bit` field means
the catalogue's size is bounded by the width of the integer holding a soldier's
mask. If more kinds are wanted than bits available, that is a real decision — a
second mask word, or a smaller catalogue — and it should be made deliberately
rather than discovered when the thirty-third upgrade silently does nothing.
