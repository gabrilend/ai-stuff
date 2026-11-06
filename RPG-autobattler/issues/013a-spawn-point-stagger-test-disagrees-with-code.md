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
