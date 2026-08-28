# 208 — A Wave Knows When It Is Gone

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 205, 207 |
| Blocks | 403 |
| Reads | [waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md) |
| Open questions | none |

## Current behavior

A wave is a record and every body carries its id for life. A death decrements
that one wave's living count and nothing scans. Fully defeated means the count reached
zero **and** something killed at least one member — both halves, because a wave can
also empty by walking into a library.

The wipe pays the team that did not spawn it, one draw.

## Intended behavior

A wave is **fully defeated** when `living_count` reaches zero **and**
`killed_any` is 1. Both halves are necessary:

- `living_count == 0` on its own is not enough. A wave can also empty out by its
  members walking into an enemy library and ending the match, or by being cleared
  at match end. Neither should pay anybody.
- `killed_any` is set the first time a member dies to enemy damage of any kind —
  enemy soldiers, enemy towers, or an enemy challenge monster. A wave that dies
  entirely to towers still counts. The vision does not distinguish, and neither
  does this.

The check runs in the reap pass, immediately after a death is applied, on the
wave record the dead soldier points at. **It does not scan all waves every tick.**
One death touches one wave.

The wave system's whole responsibility ends at raising one event:

    wave_wiped { wave_id, spawning_team, killing_team, lane, tick }

Who that event pays is issue 403's business, not this one's. Keeping the
detection and the reward apart matters because the reward rule is the least
settled thing in the design and will very likely change — and when it does, the
detection should not have to.

## Suggested implementation steps

1. Add the decrement of `living_count` to the reap pass, and the setting of
   `killed_any` to the resolve pass where the killer is known.
2. Add the wipe check immediately after the decrement, guarded on `settled` so a
   wave is only ever announced once.
3. Raise the event into the tick's event list, which the snapshot carries out to
   the viewer.
4. Write a test: spawn a wave, kill every member with enemy fire, assert exactly
   one event, with the right teams named.
5. Write a test: spawn a wave, let every member reach the enemy library and be
   removed, assert **no** event.
6. Write a test: kill some members and let the rest be removed at match end,
   assert no event — because a wave that was never finished off should not pay.

## Related documents and tools

- [Waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- Issue 403, which consumes this event

## Settled

The **killing** team draws. This issue still does not act on it — detection and
reward stay in separate issues, because the detection is stable and the reward is
the most likely thing in the design to be retuned. The event carries both team
numbers; issue 403 picks one.

