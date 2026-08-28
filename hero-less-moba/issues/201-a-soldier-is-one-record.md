# 201 — A Soldier Is One Record

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 103 |
| Blocks | 202, 203, 204, 303, 503, 606 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

One soldier record as parallel flat arrays, grouped as identity, place, body and
mind. Wave units, heroes, guards and monsters are all this record with different
numbers in it, and there is one movement routine, one targeting routine and one attack
routine between them.

## Intended behavior

**One soldier record.** Wave units, hero units, tower guards, and challenge
monsters are all the same record with different values in their fields. There is
one movement routine, one targeting routine, one attack routine, and no second
system anywhere.

The vision is explicit about why: hero units "behave like regular units so we
better make sure that our unit AI is top notch." Taken literally, that becomes a
constraint with teeth — anything worth giving a hero has to be expressible as a
field on the common record, which keeps the brain small enough to actually be
good. The alternative, a separate hero controller, is how lane-pushers end up
with soldiers that are visibly stupider than heroes. In a game with the heroes
subtracted out, visibly stupid soldiers are the entire product.

The four flavours differ only as follows:

| Flavour | What is different |
| --- | --- |
| wave unit | The baseline. No abilities. `owner` is 0. |
| hero unit | Larger numbers, one or two abilities, obeys sign-posts, `owner` is a player. |
| guard | Has a `leash_node`. Patrols instead of advancing. |
| monster | Very large numbers. Ignores sign-posts, small acquisition range, targets structures at soldier priority. |

The fields group as identity, place, body, mind, and modifiers, and that grouping
is also how they cluster in memory, because it is how the tick's passes touch
them.

One field deserves its own note in the source: `upgrade_mask` is stamped **once,
at spawn**, and never recomputed. This is the largest performance decision in the
unit system, and it has a design consequence that must be told to players
outright — moving an upgrade out of a lane does not weaken the soldiers already
walking in it. They keep what they were born with until they die.

## Suggested implementation steps

1. Write the soldier store on top of the flat-array store from issue 103. Every
   field is an integer or a double; nothing is a table and nothing is nil.
2. Write the unit catalogue as a table of archetype rows — one row per wave unit
   type, hero, guard, and monster — holding the base values for body fields.
3. Write `spawn_soldier(world, archetype, team, lane, node, owner)`, which copies
   the archetype's row into a fresh slot and stamps the mask.
4. Write the companion `.info.md` beside the source file, listing every exported
   function and every field down to its primitive type. It is the file people
   read; the source is for when something specific is misbehaving.
5. Write a test that spawns one of each flavour and asserts every field is
   populated and none is nil.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The unit catalogue (this issue creates it)
