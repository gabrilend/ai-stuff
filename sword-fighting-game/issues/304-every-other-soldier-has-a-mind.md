# 304 — Every Other Soldier Has A Mind

| | |
| --- | --- |
| Phase | 3 — The sword |
| Blocked by | 102, 203, 205, 206, 301, 302, 303 |
| Blocks | 305, 602 |
| Files | `src/012-soldier-mind.lua` |

## Current behavior

Built in `src/012-soldier-mind.lua`: march, engage, recover, harry and
fall_back as a table of states. Minds swing from the bend half the time and
otherwise from the side opposite their last slash, guard once per enemy
swing seen with a chance, and never backstep while fatigued. In progress:
criticals between minds are rare and flanks almost never happen (see the
open question).

## Intended behavior

Each soldier without a hand on it is run by a small mind that produces the
same intent record the player's input does (forward, side, guard, swing,
u_delta, dodge), so the rules cannot tell a mind from a person.

The mind is a set of states in a dispatch table:

| State | Does | Leaves when |
| --- | --- | --- |
| march | walks to its formation slot, which advances along the push direction | an enemy is within engage range |
| engage | closes to reach of its lock, moves its sword along the U to a chosen side, swings when in reach and its stamina is above its caution level, guards when the lock is winding up | no enemy within engage range: back to march; stamina below its caution level: recover |
| recover | guards and steps back a little (backing up only while fatigue is below the trip threshold, so minds do not trip themselves on purpose) | stamina above its comfort level |
| harry | (with the harry perk) after each swing, the whole battalion steps back together for a moment, then in | the moment passes |

Minds draw their choices (which side to swing from, when) from the `minds`
stream, and have a little reaction delay (configuration) so they are beatable.

## Suggested implementation steps

1. Write the states and the transitions; the formation slot comes from the
   battle (305).
2. Test: two lone minds facing each other end up fighting; a mind never
   backsteps while fatigued.

## Open questions

- Should minds step into their blows and seek flanks more, or should the
  momentum threshold for a critical drop?
