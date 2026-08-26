# 027-upgrade-table

The upgrade catalogue: one row per kind, and the deck built from them.

## What it is for

A body carries a small **integer count** of each kind rather than a bit set,
because duplicates stack and a bit set cannot count.

## Exports

| Name | Type | Meaning |
| --- | --- | --- |
| `kind` | array of rows | The catalogue. A count vector has one slot per entry here. |
| `deck` | table | How the shared deck is built. |

## A kind row

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Shown in the panel and in refusals. |
| `glyph` | string | One character, for badges and for the terminal viewer. |
| `colour` | double[3] | RGB, 0 to 1. The chip, the pip on a body, the badge on a tower. |
| `reaches` | integer | **1 melee only, 2 ranged only, 3 both.** |
| `add` | table | Additive terms, applied first. Keys are body fields. |
| `mul` | table | Multiplicative factors, applied second. |
| `tower` | table | What it does when slotted into stone. May be empty. |

## The two fields that are easy to confuse

`add` is summed and applied **first**; `mul` is multiplied and applied **second**.
That order is fixed across the whole game, so two teams holding the same upgrades
in a different sequence arrive at the same numbers.

`reaches` means two related things. In a lane it decides which half of a wave the
upgrade touches, which is what makes placing into a lane a decision about
*composition* and not only about quantity. In stone it decides which half of the
stone it touches: melee kinds go to the tower's **guards**, ranged kinds to the
**tower itself**, common ones to both. A tower shoots from a distance and a guard
is a body standing in front of it, so the split falls out of what they are rather
than being a second rule.

## Two rows worth reading before you edit any of them

**Drums** is the one kind whose multiplier sits *below* one, because cooldown is
the one stat where smaller is stronger. Next to seven rows of factors above one it
looks like a typo.

**Boots** has an empty `tower` table, and that is a real placement decision rather
than a gap: stone does not walk, so Boots in a lane is a push and Boots in stone
is a wasted slot.

## The deck

`copies_per_kind` decides how long the shared sequence is. **Both teams draw from
one sequence**, at their own index into it — so what the enemy holds is knowable
in aggregate, and what you learn by looking at their frontline is *where they put
it*. That is the whole of the fog in this game.
