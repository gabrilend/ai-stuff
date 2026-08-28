# 506 — Spawning Onto a Tower, and Being Pushed Back

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 301, 503 |
| Blocks | 703 |
| Reads | [hero units](../docs/012-hero-units.md) |
| Open questions | B4 |

## Current behavior

A hero can be bought onto any of its team's standing towers, **unless an enemy
stands inside that tower's command radius** — in which case the purchase is refused and
the refusal names the nearest tower behind it that would accept one.

Refused, never redirected. A silent redirect is a purchase you did not make, and in a
game where a hero costs a minute of income that matters.

## Intended behavior

The second spawn destination. A player picks any of their own living guard
towers, and the hero appears at its node — **unless enemy soldiers are within a
threshold radius of that tower**, in which case the spawn is refused and the
player is directed one tower further back.

This rule is the whole texture of hero spawning, and it is worth stating as a
sentence a player would say out loud:

> **You cannot reinforce the tower that is actually under attack. You reinforce
> the one behind it, and walk.**

A tower under pressure is a tower whose reinforcements arrive late, by design.
That is what makes the outer towers worth defending *before* they are in trouble
rather than after, and it is what stops a player from teleporting a wall into
every emergency.

"One tower back" is resolved by **milestone**, not by distance: from the refused
tower's milestone index, step toward the player's own library until a tower is
found whose radius is clear. If none is, the library itself is the fallback,
which is destination three. The player is told which tower they were pushed back
to and why — never silently relocated, because a hero appearing somewhere
unexpected is indistinguishable from a bug.

## Suggested implementation steps

1. Extend `spawn_hero` for destination kind 2, taking a structure id.
2. Refuse if the structure is not this team's, is dead, or is a library — the
   library is its own destination with its own rules.
3. Write the enemy-proximity check against the milestone buckets from issue 204,
   not a scan.
4. Write the step-back walk over the lane's milestone list, ending at the
   library.
5. Return a **distinct reason code** for "pushed back" as opposed to "refused",
   and have the viewer say which tower it landed on.
6. Write a test: enemies beside the outer tower, spawn requested there, assert
   the hero appears at the inner tower with the pushed-back reason recorded.
7. Write a test: enemies beside every tower in the lane, assert the library.

## Related documents and tools

- [Hero units](../docs/012-hero-units.md)
- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)

## Still open

How large is the threshold radius? Too small and the rule almost never triggers,
so reinforcing under fire is free. Too large and a single enemy scout wandering
near a tower locks a player out of half the map.
