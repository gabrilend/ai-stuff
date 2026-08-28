# 306 — Felling a Tower Pays Three

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 205, 301, 302, 303 |
| Blocks | 403, 408 |
| Reads | [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md) |
| Open questions | none |

## Current behavior

A felled tower kills its guards immediately and pays three separate draws to the
team that knocked it down — three things to place, not one worth three times as much.

The lane's slotted upgrades are untouched, because an upgrade is slotted into a lane's
stone as a whole and there is nothing in a felled tower to give back.

## Intended behavior

When a tower's health reaches zero, five things happen in this order:

1. **It is marked dead**, and its node's `structure` field is cleared to 0, so
   soldiers stop treating it as an obstacle or a target.
2. **Its living guards die immediately.** They do not survive their tower.
3. **Three upgrades are drawn into the destroying team's chest**, one after
   from that team's own index into the shared deck. See issue 403.
4. **Nothing happens to the lane's slotted upgrades.** An upgrade is slotted into
   a lane's stone as a whole, never into one tower, so a felled tower has nothing
   in it to lose. *Settled; see [open questions](../docs/020-open-questions.md),
   A5.*
5. **The rubble stays** in the structure array, so the renderer can draw it and
   the post-match report can find it.

Three separate draws, not one upgrade worth three times as much. The vision says
"three unit upgrades" and the plurality is the point: felling a tower should
trigger a burst of *placement decisions*, three things to argue about at once,
which is a burst of teamwork at the exact moment a team has just done something
well together.

Towers do not regenerate and do not come back. A felled tower is a permanent
change to the shape of the match.

This issue depends on the draw machinery from phase 4. Until issue 403 exists,
raise the event and let it fall on the floor — but raise it, with the right
count, so that wiring it up later is one line.

## Suggested implementation steps

1. Write the tower-felled path in the resolve pass, next to the soldier death
   path, sharing the same structure.
2. Raise `tower_felled { structure_id, owning_team, destroying_team, lane, milestone, tick }`.
3. Kill the guards through the ordinary kill path so that their deaths pay
   personal resource normally.
4. Write a test that fells a tower and asserts exactly three draw events for the
   right team.
5. Write a test that asserts a felled tower's node no longer blocks or attracts
   soldiers.

## Related documents and tools

- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)
- Issue 403, which owns the draw

## Settled

**Upgrades slotted into a lane's stone are untouched when a tower falls** — an
upgrade is slotted into the lane's stone as a whole, never into one tower.

The consequence this issue should carry: **a tower upgrade cannot be taken away
by anything the enemy does.** Only a siege-surge dislodges one. That makes stone
strictly safer than soldiers as an investment, and the numbers have to pay for it
— stone must be worse at *pushing* by enough to be obvious. Issue 804 should
carry the ratio of stone placements to lane placements as a headline number; if
it drifts hard toward stone, this rule is why.

See [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md).

## Still open

Nothing blocking this issue.
