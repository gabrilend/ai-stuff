# Issue 013a: Spawn Point Stagger Test Disagrees with the Code

## Current Behavior
`tests/test_spawn_point.lua`'s `test_spawn_timing` queues two units on one
sub-path slot. They get spawn timers of 1.0 s and 1.2 s. After 1.5 s it
expects one unit released and one still queued. `SpawnPoint:update` in
`src/entities/spawn_point.lua` counts down every queued unit's timer at
once, so both reach zero by 1.5 s and both are released. The test fails
with "One unit should have been released". This was hidden while the
suite hung on `Vector2.lerp`, which `adjust_queue_positions` calls after
each release.

## Intended Behavior
Either units leave a slot one at a time, each timer starting once the unit
reaches the front, or the test expects simultaneous countdowns.

## Suggested Implementation Steps
1. Decide which is meant. Since `adjust_queue_positions` moves the queue up
   after each release, one at a time reads as the intent.
2. If so, count down only the front unit of each slot's queue (or start
   the next timer on release). Otherwise change the test's expectation.
3. Run `tests/test_spawn_point.lua` under luajit and lua 5.4 to the end.

## Related Issues
- 013-add-spawn-points-for-both-players.md (completed)

## What Happened

The code was wrong for the stagger test, and the test was wrong for lane
capacity.
- **Stagger: one at a time.** `SpawnPoint:update` now counts down only the
  unit at the front of each sub-path slot. When it's released, the queue
  moves up and the next unit's timer starts. Two units queued with timers
  of 1.0 s and 1.2 s now leave at 1.0 s and 2.2 s, as `test_spawn_timing`
  expects.
- **Lane capacity.** Once the suite got past the timing test, a third
  disagreement showed. `test_lane_availability` put five units in one
  sub-path slot, but issue 013's design, and `max_queue_size`, cap a slot
  at three. The test now spreads the five over two sub-paths and still
  expects lane 1's capacity to drop to 5. It also now checks that a full
  slot refuses a fourth unit.

`tests/test_spawn_point.lua` runs to the end under LuaJIT and Lua 5.4, and
`run` runs it.

### Decisions
- **One at a time is the intent.**
  - `adjust_queue_positions` moves the queue up after each release, which
    only makes sense if units leave in turn.
  - The test expects it.
  - It keeps a lane from emptying its whole queue in a 0.2 s burst.
- **Each unit keeps the staggered timer it was given on arrival**
  (1.0 s + 0.2 s per unit ahead of it). The test checks that stagger, and
  a unit further back waits a little longer once it reaches the front.
- **The lane-capacity test was the wrong one**, because it contradicted
  the documented three-per-slot design. Its expectation (capacity 5)
  stays. Only how the five units are placed changed, and it gained a
  check.
