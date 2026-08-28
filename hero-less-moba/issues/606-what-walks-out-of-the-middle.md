# 606 — What Walks Out of the Middle

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 201, 203, 204, 601, 605 |
| Blocks | 607, 608 |
| Reads | [boons and the challenge](../docs/015-boons-and-the-challenge.md) |
| Open questions | B9 |

## Current behavior

Three named monsters in a fixed order — the Pillar Orc, the Field Dragon, the
Eternal Golem. They are a third team, hostile to everything including each other, and
each is assigned to the team whose base it walks at. That team is paid the boon
whoever lands the blow.

The Golem cannot be hurt at all, acquires nothing, and walks.

## Intended behavior

On the tick a surge ends, **two monsters appear at the center lane's midpoint**,
one per team, each walking toward that team's base. They never meet and never
fight each other.

**The three challenges are always the same three, in the same order.** No
randomness in which appears — the challenge index selects the row.

| | Challenge | | Ends when |
| --- | --- | --- | --- |
| 1 | **The Pillar Orc** | killable | both are dead |
| 2 | **The Field Dragon** | killable | both are dead |
| 3 | **The Eternal Golem** | **cannot be killed** | **a library falls** |

### A monster is a soldier record

`flavour = 4`, very large numbers, same movement and targeting and combat. Three
behavioural differences, all fields rather than special cases:

- **Ignores sign-posts.** Nothing reroutes it out of the center lane.
- **Small acquisition range relative to its size**, so it wades through a
  frontline toward the base rather than parking in it. A monster that stopped at
  the first soldier it met would never arrive.
- **Targets structures at soldier priority** rather than below it, so it does not
  walk past a tower to be shot in the back.

Killing one of the first two pays every player on the team that landed the last
blow — the largest single payout in the game.

### The Golem is the same machinery pointed at a different number

It has **no health**. Damage feeds a rolling window; **speed is a function of
that window's total; the window decays rapidly.** Keeping it slow therefore needs
continuous damage, and stopping means it is as fast as it ever was.

It also **never stops moving** — it attacks while walking — and it **pays
nothing**: no last blow, no resource, no boon, no calm afterwards.

Why this ends a match, and why progress not being kept is the whole design, is in
[boons and the challenge](../docs/015-boons-and-the-challenge.md), along with the
line that describes what the Golem is. That line should be read before this is
built.

## Suggested implementation steps

1. Add the three archetypes to the unit catalogue. The challenge index selects
   the row; there is no draw.
2. Spawn **two** of the selected archetype on the surge-end transition, at the
   center lane's milestone 4, each facing a different way.
3. Set the three behavioural fields, and comment each with what it prevents.
4. For the Golem, write speed as a **damage-per-tick to speed-multiplier**
   function over a decaying rolling window. The decay rate is the single most
   important number in the endgame.
5. Route damage to a Golem into that window instead of into health. **Do not give
   it a huge health value and special-case the death** — that leaves a way for it
   to die.
6. Give its speed a floor above zero, so a big enough team can never stop it
   completely, and a ceiling, so a wiped team does not watch it sprint.
7. Confirm all three walk into a base correctly, through the open interior from
   issue 305, meeting every base guard at once.
8. Write a test that the Orc and the Dragon do not stall permanently against a
   healthy frontline. **If they stall, the first two challenges have no
   deadline**, and this is the failure mode most likely to be found late.
9. Write a test that a Golem's speed recovers to the ceiling within the intended
   window when damage stops.

## Related documents and tools

- [Boons and the challenge](../docs/015-boons-and-the-challenge.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)

## Still open

**How much health do the Orc and the Dragon have?** B9, and it has to be
expressed against what a team can realistically field at that point in a match
rather than as a bare number.

**What stops a team ignoring its Golem and pushing instead?** If both teams must
hold their own, neither can spare anything for offence, and the match ends by
whichever Golem arrives first — so the winner is whoever *held* longest rather
than whoever *pushed* furthest. That may be exactly right for an endgame, or it
may make the final minutes a defensive stalemate with a countdown.
