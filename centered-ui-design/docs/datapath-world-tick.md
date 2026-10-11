<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of one simulation step. Updated by issues that change
     the simulation (phase 1 mostly). -->

# Datapath: one world tick

## Data it works on

| Structure | Fields (down to primitives) |
|---|---|
| world | `seed` (integer), `tick` (integer, count since start), `team_size` (integer 1–4), `tiers` (list of tier bands), `stands` (list of stands), `couriers` (list of couriers), `factories` (list), `treasury` (resource counts) |
| tier band | `index` (integer, 1 = nearest), `inner_tier_distance` (number), `outer_tier_distance` (number), `terrain` (grid of cell kinds, one small integer each) |
| position | `tier_distance` (number: 0 = hub, 1.0 = outer edge of tier 1, 2.5 = halfway through tier 3), `angle` (number, radians, 0 = up/north, increasing clockwise) |
| stand | `id` (integer), `owner_seat` (integer, which stand-in), `position` (position), `units` (list of units), `current_order` (order or the word `idle`), `speed_tiers_per_second` (number) |
| unit | `kind` (string, a choice id), `health` (number), `attack` (number), `range` (number, in tier-distance), `shield` (number) |

Positions are in **tier-distance**, not pixels or meters. This is what makes
the map "not to scale": a stand moving at 0.1 tiers per second crosses every
tier band in 10 seconds regardless of how big that band is drawn.

## Steps of one tick

```
 commands from view ─▶ 1. accept commands (become couriers, see datapath-orders)
                      2. advance couriers; deliver arrivals to their stands
                      3. split stands by direction ─┬─▶ station: move + fight, direction A
                                                    ├─▶ station: move + fight, direction B
                                                    └─▶ ...
                      4. join station (waits for every direction, combines in direction order); settle fights that cross a quadrant edge
                      5. production, income, votes due this tick
                      6. check fronts (outpost at current tier destroyed?) ─▶ level-up
                      7. publish snapshot ─▶ view
```

1. Seeded randomness: the world owns one random stream per purpose (combat,
   offers, terrain) all derived from `seed`, so adding a random call in one
   area does not shift results in another.
2. Fixed tick: the simulation advances in steps of exactly 1/20 second of game
   time, regardless of the frame rate.
3. Direction split: each direction is its own soramech station; each runs the
   moment its inputs arrive, on whatever core is free, and returns new
   positions and damage dealt. Stands within a short distance of a
   quadrant edge are handled by the join station, so two
   stations never decide about the same pair of units.
