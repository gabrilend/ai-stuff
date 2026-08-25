# 503 — A Hero Is a Soldier You Bought

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 201, 501, 502 |
| Blocks | 504, 505, 506, 507, 509 |
| Reads | [hero units](../docs/012-hero-units.md), [commanders and personal resource](../docs/011-commanders-and-personal-resource.md) |
| Open questions | none |

## Current behavior

Resource accumulates and buys nothing.

## Intended behavior

A hero unit is a soldier record with `flavour = 2` and `owner` set to the buying
player. Same movement, same targeting, same combat, same brain — the differences
are values:

| | Wave unit | Hero unit |
| --- | --- | --- |
| Combat weight | 1 | about 2.5 |
| Abilities | none | one or two, automatic |
| Obeys sign-posts | no | yes |
| Lane upgrades | every one in its lane | **none, ever** |
| On death | nothing | nothing. It is gone. |

"About 2.5" is a **weight**, not a stat — a hero might be 2.5× the health at 1×
the damage. The balance validator checks each hero's computed weight lands in the
intended band, so the ratio is enforced by a tool rather than by everybody
remembering it.

### No cap on heroes. A ceiling on the wallet.

A player may field any number of heroes at once. What is limited is **how much
resource they can hold**: income arriving at the ceiling is **lost**.

The ceiling **grows as the match goes on**, rising at each calm alongside the
boons — tight early, roomy late.

Why a ceiling is a better limiter than a hero cap, and why the growth is tied to
the calms, is in
[commanders and personal resource](../docs/011-commanders-and-personal-resource.md).
The short version for building: it never refuses a purchase, it just means a full
wallet is losing every kill the team lands.

### Buying is open in every phase

During a surge and a challenge, heroes arrive normally. **During the calm,
purchasing stays open but the hero waits at the library** until spawning resumes,
then marches out with the first wave — because during the calm every body on the
field is walking home and a new one would have nowhere to go.

That makes the calm the one moment a player can deliberately build an opening
push.

### Resource buys two things

Heroes, and **rerolls** (issue 411). Nothing else — no shop, no upgrade purchase,
no tower repair, no ability unlock.

## Suggested implementation steps

1. Add hero archetypes to the unit catalogue with a price field.
2. Write the `spawn_hero` price check and deduction. Refuse loudly on insufficient
   funds; **never partially deduct**.
3. Add `resource_max` and `resource_wasted` to the player record. Clamp on
   payout and accumulate the difference — the report wants it and so does the
   interface.
4. Raise `resource_max` at each calm.
5. Add a **waiting** spawn state for heroes bought during the calm: the body
   exists, stands at the library, does not move or acquire until the phase changes.
6. Track `hero_alive` per player for the viewer and the report.
7. Write the balance validator's combat-weight check.
8. **Show a player at or near the ceiling loudly and continuously.** An invisible
   overflow is a punishment nobody can see, which is the worst kind.
9. Write a test that a player at the ceiling gains nothing from a kill and that
   `resource_wasted` rises by the right amount.
10. Write a test that buys a hero and asserts the deduction and the right owner.

The three spawn destinations belong to issues 505, 506, and 507; this issue only
puts a hero on the ground at the library, the simplest of them.

## Related documents and tools

- [Hero units](../docs/012-hero-units.md)
- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)

## Still open

**What is the ceiling?** High enough to afford the most expensive hero on your
roster with room to consider; low enough that a full surge cannot be banked
through. **Those two constraints may not both be satisfiable at a single value**,
which is why it grows — but the curve still has to be found, and issue 804 is
where.
