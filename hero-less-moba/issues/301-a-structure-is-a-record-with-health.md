# 301 — A Structure Is a Record With Health

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 101, 103, 205 |
| Blocks | 302, 305, 306, 307, 408 |
| Reads | [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md), [the base and the library](../docs/008-the-base-and-the-library.md) |
| Open questions | none |

## Current behavior

Structures are records with health, standing on the map's sites: three towers per
lane per team and one library each. A felled one stays in the array as rubble, so the
renderer can draw it and the report can find it.

The map validator counts them, which it did not used to — a refactor once deleted the
line that placed them and every existing check passed.

## Intended behavior

One **structure record** covering guard towers, base guard towers, and libraries.
Same store, same damage path, distinguished by a `kind` field.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Index in the structure array. |
| `team` | integer | 1 or 2. |
| `kind` | integer | 1 lane tower, 2 base tower, 3 library. |
| `lane` | integer | 1–3. Base towers keep the lane whose mouth they cover. |
| `milestone` | integer | 1, 2, or 3 from the owning team's end. 0 for a library. |
| `node` | integer | Where it stands on the path graph. |
| `health`, `health_max` | double | Current and full. |
| `damage` | double | Per arrow. Zero for a library. |
| `range` | double | In paces. A plain radius; it does not know what a lane is. |
| `cooldown`, `cooldown_max` | integer | Ticks between arrows. |
| `target` | integer | Soldier id, or **0**. |
| `guard_slot` | integer[] | Soldier ids of living guards. Zeros for empty. |
| `guard_timer` | integer | Ticks until the next guard is put on the ground. |
| `alive` | integer | 1 or 0. Rubble stays in the array. |

Eight towers per team: two on each lane at milestones 2 and 3 from that team's
end, and three inside the base at milestone 1 of each lane. Plus one library.

**Every guard tower is exactly as strong as every other.** No tiers, no
inner-is-tougher. That flatness is what makes tower upgrades interesting later: a
slotted upgrade becomes the *only* thing distinguishing one lane's stone from
another's, which makes the slotting decision visible from across the map. If
towers already differed, a slotted upgrade would be a small adjustment to an
existing hierarchy and nobody would notice it.

Structures have **no armour** and take full damage. Siege maths stays a number a
player can hold in their head: this many swings fells a tower.

The library's health is stored as a **ratio to tower health** — about one and a
half — not as an absolute number, so that retuning towers retunes the library
automatically. A validator checks the ratio holds.

Structures do not regenerate and do not come back.

## Suggested implementation steps

1. Write the structure store on the flat-array pattern from issue 103. It is
   small and fixed-size and needs no free list.
2. Populate it from the map's tower and library sites at world creation, and set
   each node's `structure` field to the id standing on it.
3. Extend the pending-damage buffer to cover structures, and the resolve pass to
   apply it to them.
4. Extend the soldier targeting from issue 204 to see structures, at the priority
   it already specifies — below soldiers.
5. Write the balance validator check on the library-to-tower health ratio.
6. Write a test that fells a tower with a known number of swings and asserts the
   count matches the catalogue.

## Related documents and tools

- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)
- [The base and the library](../docs/008-the-base-and-the-library.md)
