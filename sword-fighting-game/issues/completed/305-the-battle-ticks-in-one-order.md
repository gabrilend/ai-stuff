# 305 — The Battle Ticks In One Order

| | |
| --- | --- |
| Phase | 3 — The sword |
| Blocked by | 202, 205, 303, 304 |
| Blocks | 105, 405, 406, 501, 502, 701 |
| Files | `src/014-the-battle.lua` |
| Reads | `docs/datapath-battle-tick.md` |

## Current behavior

Built in `src/014-the-battle.lua`. One change from the plan: strikes
resolve in two passes (collect every strike of the tick, then resolve them),
because with one pass a soldier felled by a lower id on the same tick lost
its falling blow and team 1 won about two battles in three. After the fix,
256 battles split 123 to 133. Regression case in tests/033-the-sword.lua.
Battalion origins wheel toward the nearest enemy battalion that still has
soldiers standing.

## Intended behavior

A battle record holds: the battlefield, the soldiers (an array, in id
order), the two contingents (each a list of battalions; a battalion has its
formation origin, its facing and its push direction), the region kind, the
time, the tick count, the counters for the receipt, the event list of the
current tick, the volleys in flight (501), the shield-wall flags, the player's
soldier (or false), and the outcome (false, or the winning team).

**Setup** places each contingent's battalions side by side along its own
edge, facing the other, in formation (4 wide × 3 deep by default, one cell
apart), the player's soldier in the front rank of the middle battalion. The
enemy's push direction shifts where it deploys (head on, or toward one wing).

**One tick**, always in this order:

1. clear the tick's events;
2. intents: the player's from the view (or its mind headless), everyone
   else's from their minds;
3. locks and the U (301);
4. movement and tripping (205, 206);
5. swings advance; strikes are resolved in soldier-id order (303);
6. volleys fly and land (501);
7. stamina restores (204); timers (stagger, trip) count down;
8. the formation origins advance along their push directions;
9. the break check: a contingent with a quarter or fewer standing breaks,
   and the other team is the outcome.

Order by id, never by table iteration order, so a battle is the same on
every run.

## Suggested implementation steps

1. Write setup and the tick.
2. Test: the same seed gives the same outcome and counters twice; a battle
   always ends within the configured time limit; a broken contingent gives
   the other side the outcome.
