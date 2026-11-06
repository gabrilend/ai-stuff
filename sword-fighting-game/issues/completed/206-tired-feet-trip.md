# 206 — Tired Feet Trip

| | |
| --- | --- |
| Phase | 2 — Bodies on the field |
| Blocked by | 102, 204, 205 |
| Blocks | 304 |
| Files | `src/007-stamina.lua` (the trip rules), `src/008-movement.lua` (where they are asked) |

## Current behavior

Built: the rules in `src/007-stamina.lua`, asked from `src/008-movement.lua`
when a backstep or sidestep begins. Minds never wish a backstep while
fatigued, so between minds trips are rare; they are a hazard for the person.
Tested in tests/032-bodies-on-the-field.lua.

## Intended behavior

Two rules, both asked by movement on the tick a step begins:

1. **Backstepping while fatigued trips, always.** When the soldier backsteps
   (the backward wish passes a small threshold) and its fatigue is above the
   configured trip threshold, it trips.
2. **Sidestepping while guarding trips one time in four.** Only while
   guarding; the roll is made once per sidestep begun (a sidestep begins when
   the side wish rises past its threshold from below), from the `movement`
   stream, with the configured chance.

A tripped soldier lies down for the configured time: no movement, no swing,
no guard; its swing in progress is dropped. Trips count in the receipt.

## Suggested implementation steps

1. Keep on the record whether the soldier was already sidestepping or
   backstepping last tick, so the rule fires on the beginning of a step, not
   on every tick of it.
2. Test: a fresh soldier backsteps safely; a fatigued one trips; over many
   guarded sidesteps the trip share is near one in four; unguarded sidesteps
   never trip.
