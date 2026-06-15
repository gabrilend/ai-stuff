# 116 — Factory Placement & Production

## Status

TODO

## Current behavior

There is no factory. Units exist only because of the startup spawn
from issue 106.

## Intended behavior

A single UI button in a corner of the screen reads "Place Factory."
Clicking it enters *placement mode*:

- A ghost factory follows the terrain pick point (using
  `terrain_pick`).
- Left-click commits placement. Right-click cancels.
- Esc also cancels.

Once placed, the factory:

- Renders as a larger box (or short cylinder, distinct from units).
- Owns a production timer. Every `FACTORY_BUILD_INTERVAL_TICKS`
  (e.g. 10 seconds × `SIM_TICK_HZ`), it produces one unit at its
  position, with a default rally of "stand here."

The factory belongs to the player's team. Phase 1 supports exactly one
factory per game (multi-factory is a Phase 2+ concern). When a
factory already exists, the button is disabled.

## Suggested implementation steps

1. Create `src/080-factory.c` / `.h` with a single `Factory` struct
   (placed bool, position, build_timer, rally chains).
2. Render a button overlay using raylib's text drawing — a clickable
   rectangle in screen space. Track hover/click state on main thread.
3. On button click, set `placement_mode = true` on main thread.
4. Each frame in placement mode, draw a translucent ghost of the
   factory at the picked terrain point.
5. On left-click while in placement mode, emit
   `FACTORY_PLACE(world_x, world_y)` and exit placement mode.
6. In sim, on `FACTORY_PLACE`, write the factory's position and start
   its build timer.
7. Each sim tick, advance the build timer; when it reaches the
   interval, spawn a new unit at the factory's location and reset the
   timer. The new unit gets its rally chain from the factory's
   current chain set (rally chains arrive in issues 116/117 — for now,
   the unit just spawns and stands).

## Related documents

- `docs/002-mechanics.md` — factory rules.
- Issues 117, 118 — rally points.

## Notes

A single factory in Phase 1 keeps the round-robin logic for chains
(issue 118) testable in isolation. Multi-factory adds a layer of
"which factory is selected for rally editing" that we'd rather defer.

## Task pool integration

This issue is the cleanest illustration of "different priorities
for different aspects of the same system." The factory has two
distinct kinds of work:

**Production countdown — priority 5.** A self-rescheduling task
that decrements the build timer each tick and spawns a unit when
it reaches zero. This is the user's own example: "factories which
update their production display percentage value every tick at
low priority."

```
factory_production_task_actions = [
    [0] decrement_build_timer
    [1] check_if_zero_spawn_unit_if_so
    [2] reset_timer_if_unit_spawned
    [3] reschedule_self_at_priority_5
]
```

Priority 5 is a deliberate middle ground: it WILL get scheduled
each tick (the cycler reaches priority 5 within every cycle of
length 4+5=9 steps), so the timer doesn't drift. But it doesn't
preempt projectile-arc updates (priority 1) or LoS / movement
(priority 2). On a busy combat tick, factory production might run
a tick or two late; nobody notices because production intervals
are seconds.

**Production display percentage — priority 9.** A separate self-
rescheduling task that computes `(interval - timer) / interval`
and writes it to the snapshot's factory display field. Pure UI
update; one tick of staleness is invisible. Priority 9 means it
runs only when the cycler reaches level 9 in its 1; 1,2; 1,2,3;
... walk — roughly once every 45 cycler steps.

```
factory_display_task_actions = [
    [0] read_factory_timer_state
    [1] compute_percentage
    [2] write_to_snapshot_display_field
    [3] reschedule_self_at_priority_9
]
```

Splitting the two is the design point: combine them and the
display update steals a priority-5 slot from the actual production
work, which has no benefit. Separate, the display can fall behind
under load without affecting anything that matters.

**Placement / cancel input handling — priority 3.** Spawned once
per `FACTORY_PLACE` event. Same priority class as other input
handlers (issues 108, 109, 110).
