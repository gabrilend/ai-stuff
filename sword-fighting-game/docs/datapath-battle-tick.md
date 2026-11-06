# Datapath: one battle tick

What happens, in order, in one fixed step of a battle
(src/014-the-battle.lua). The order never changes and nothing in it walks a
hash table, which is why a seed and a script decide a battle completely.

```
1. events of the last tick cleared
2. intents      player soldier ◄── person's intent (front rank) or its mind
                every other    ◄── soldier mind (012): march / engage /
                                   recover / harry / fall_back
3. per soldier  lock (009): nearest enemy, half a second to switch
                facing turns toward the lock (or the battalion's facing)
                the intent's u_delta moves the sword along the U
                guard = intent.guard and able and not swinging
                intent.swing ──► swing begins (010), stamina spent
4. movement     (008) yields and dodges carry on by themselves;
                walking: trip checks (007) ──► dodge ──► step with the
                occupancy rules: enemy cell = wall; ally cell = half speed,
                then trade cells and the ally yields; edge = wall
5. swings       pass 1: every swing advances; those striking this tick are
                        collected with the swing as it struck
                pass 2: each collected strike resolves (011), in id order
                ripostes begin
6. commanders   minds throw volleys and raise shields (013); darts fly and land
7. rest         stamina restores (007); trip, stagger, open, hurt timers count down
8. formations   battalion origins wheel toward the nearest standing enemy
                battalion and walk until they meet it
9. break check  a side with a quarter or fewer standing breaks; past the time
                limit the battle is a draw
```

## The records it moves

| Record | Where | Fields that matter here |
| --- | --- | --- |
| battle | 014 | field, soldiers (array by id), battalions[team] (array), darts, events, counters, shields[team], volley_range[team], trained_arc[team], commanders[team] ("mind" or "person"), time, ticks, outcome (false, 0 draw, 1, 2) |
| soldier | 006 | see src/006-soldier.info.md and issue 203: position x, y; velocity vx, vy; facing; stamina; health; u; lock; swing; guard; tripped; stagger; open; intent; mind |
| battalion | 014 | team, index, x, y (middle of the front rank, in cells), facing (radians), halted (boolean), standing (integer) |
| cell grid | 005 | width × height slots, each a soldier or false |

## Why it is shaped so

- Strikes resolve in two passes so blows on one tick are simultaneous. With
  one pass, a soldier felled by a lower id on the same tick lost the blow
  already falling, and team 1 won about two battles in three (found by
  `./run-many-battles`; tested in tests/033-the-sword.lua).
- A mind writes the same intent record a person does; the rules cannot tell
  them apart.
