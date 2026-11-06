# 207 — Health comes back on a shared timer

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 106, 201 |
| Blocks | 211 |
| Reads | [a unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | B3 |

## Current behavior

Built. `combat.health` derives a unit's health from its heal pair and its kind's
heal counter, held to the catalogue cap; `combat.hurt` derives, subtracts and
rewrites the pair with the increment of now. Every kind has its own heal
counter, `world.heal.<kind>`, and `./report-catalogue` prints each kind's heal
rhythm in ticks and seconds.

## Intended behavior

**No unit is ever walked to be healed.** Every unit kind has one heal counter
with its own period — the tanks' counter, the guns' counter, the planes'
counter — and a unit's health is **derived** whenever it is read:

    current = min(cap, health + (increment_now - health_at))

Four operations, from three integers and the catalogue's cap. When a shot lands
(issue 206) the current value is derived, the damage subtracted, and the pair
`health, health_at` rewritten with the increment of now. Between hits nothing
touches the row, and a thousand tanks healing costs exactly what one costs,
which is nothing until it is looked at.

This is the vision's design stated as a rule — "one timer that counts down all
the tanks ... when it expires, 1 hp is restored to EVERY tank" — with the walk
taken out. A counter that walked every tank when it fired would make healing an
O(units) step on a timer; this makes it free, and it is what the vision meant
by "every increment is like four operations."

**Each kind heals on its own rhythm.** Adding a kind to the catalogue is adding
a counter to the world's counter table, keyed by kind, with the catalogue's
`heal_seconds` converted to ticks at load. The intervals themselves are B3 and
are measured, not argued.

**The cap is the catalogue's.** A derived value is never above it and never
written above it. A unit spawned at full health has `health` equal to the cap
and `health_at` equal to the counter's increment at birth.

**Death is observed at damage time.** Because health only ever rises between
writes, a unit that is alive after a landing stays alive until the next one; the
die pass reads the derived value once, after the land pass, and no other code
ever asks whether a unit is dead.

This issue adds two exports to the `units` stem rather than claiming one of its
own, because health is a column of the unit row and the derivation belongs
beside it.

## Suggested implementation steps

1. Add `health(world, id)` and `hurt(world, id, amount)` to the `combat` stem's
   row in `docs/014-the-tests-come-first.md`, then to `src/NNN-combat.lua` and its
   companion. Both are pure functions of the row, the kind's counter, and the
   catalogue cap.
2. Write the world's counter table: one heal counter per catalogue kind, built at
   load from `heal_seconds` and the tick rate, through issue 106's `counter`.
3. Make `spawn` (issue 201) write the pair at birth: cap, and the kind's counter
   increment.
4. Make the land pass (issue 206) call `hurt`, which derives, subtracts, and
   rewrites — never writes `health` directly.
5. Write the reporter the documents point at instead of quoting an interval: one
   line per kind with its period in ticks and seconds.
6. Write the test's exact case as the companion's example: hit at increment N,
   hit again at N, advance to N plus one, expect one point back and not two.

## What happened

- **The counters and the birth pair came with issue 201**: `units.counters()`
  gives one heal counter per kind from the catalogue's `heal_period`, and
  `spawn` writes the cap at the counter's increment. This issue added the two
  functions over them, in the `combat` stem as the tests ask.
- **`hurt` refuses a negative or fractional amount**, so nothing heals through
  it, and lets health fall below zero for the die pass to find.
- **The reporter** is a section of `units.report()` (and so of
  `./report-catalogue`): one line per kind with its period in ticks and seconds
  and the ticks from nothing to its cap.
- **The test's exact case is the companion's example**: two hits of one at
  increment N, then one point back at N plus one.
- B3 still awaits evidence. Whether the roster's recovery (issue 304) shares
  these functions is that issue's to decide; the pair is `timers.read` and
  `timers.write`, which it can call over its own arrays.

## Related documents and tools

- [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) — the pair of integers
- [a unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md)
- [the handheld](../../docs/012-the-handheld.md) — why a derivation from three integers is a box
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **B3.** The heal interval per kind, awaiting evidence from the proving ground.
- Raised here: whether the roster's recovery (issue 304) should share this
  code or its own counter table. It is the same pair; it should be the same
  functions over different arrays.
