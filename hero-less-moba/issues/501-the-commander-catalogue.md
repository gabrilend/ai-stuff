# 501 — The Commander Catalogue

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 201 |
| Blocks | 502, 503, 509, 802 |
| Reads | [commanders and personal resource](../docs/011-commanders-and-personal-resource.md) |
| Open questions | C4b |

## Current behavior

Players are numbers with no identity and nothing to spend.

## Intended behavior

Each player picks a **commander** before the match. A commander is **not a body
on the map**. There is no avatar to move, no commander health bar, and nothing to
kill. It is two things and only two things:

1. The **name of your resource** — gold, mana, blood, embers, favour.
2. The **roster of hero units** you may buy with it.

The resource name is flair. Two commanders that both call it gold are
mechanically identical in that respect: one number, earned the same way, spent
the same way. The vision says this outright and it is worth holding to, because
the temptation to make one commander's resource behave differently — decaying,
capping, converting — is exactly the temptation that turns a clean second economy
into six special cases that have to be balanced against each other forever.

**The roster is where commanders actually differ.** Everything about how a
commander plays is in what they can put on the ground.

### commander catalogue row

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Row number. |
| `name` | string | Shown to players. |
| `resource_name` | string | Flair only. Never read by any rule. |
| `roster` | integer[] | Rows in the unit catalogue. At least three, ideally five. |

### player record, live

| Field | Type | Meaning |
| --- | --- | --- |
| `number` | integer | 1–6. 1–3 are team 1, 4–6 are team 2. A fixed mapping, not a lookup. |
| `team` | integer | 1 or 2. |
| `commander` | integer | Catalogue row. |
| `resource` | double | Current balance. Never negative. |
| `resource_earned` | double | Lifetime total, for the report. |
| `hero_alive` | integer | How many of this player's heroes are on the map. |

## Suggested implementation steps

1. Write the commander catalogue as a data table under `assets/`, with one real
   commander to start. Issue 509 fills its roster out.
2. Write the player record into the world, sized to the team-size constant times
   two.
3. Write a **commander validator**: every roster row resolves to a hero archetype,
   every roster has at least three entries, no roster is empty.
4. Add a `resource_name` lookup for the viewer, and make sure nothing else ever
   reads that field. A test that greps for it would not be excessive.

## Related documents and tools

- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)
- The commander validator (this issue creates it)

## Settled

**A handful of commanders — four or five to start — and no two players on a team
may pick the same one.** Every hero on the field belongs to exactly one player's
catalogue, and a teammate cannot buy what you can.

**The uniqueness check belongs in the lobby**, in issue 802, not here. The
simulation should be perfectly happy to run three identical commanders so that
tests and bot runs can set up whatever they like.

See [commanders and personal resource](../docs/011-commanders-and-personal-resource.md).

## Still open

**How many is "a handful"?** Four or five to start, but the roster design in issue
509 has to hold up across all of them: a second commander should **reshuffle the
jobs** rather than reskin them, and doing that badly gives every commander the
same five heroes with different names.

Note the interaction with no-duplicates: with a handful of commanders and three
per team, a large fraction of every possible team composition will be seen
constantly. There are not many combinations, and they will all be explored fast.
