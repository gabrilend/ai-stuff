# 106 — A periodic effect is a pair of integers

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 105 |
| Blocks | 112, 206, 207, 304, 403 |
| Reads | [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) |
| Open questions | none |

## Current behavior

Built. `src/032-timers.lua` makes counters, advances them, and reads and writes
the pair. The world holds its counters as named tables listed in the layout's
`COUNTERS` -- the claim counter is the first -- and the tick brings every one up
before its systems run.

## Intended behavior

A **counter** is a global periodic effect: a period in ticks, an increment that
counts how many times it has fired, and the tick it fires next. The tick
advances every counter before it walks its systems, so "the increment of now"
is settled before anything reads it. That is all a counter does. It never walks
anything.

A thing subject to the effect stores **two integers**: a value, and the
increment at which the value was written. The current value is derived on
demand:

    read(value, written_at, counter, cap)  ->  min(cap, value + (counter.increment - written_at))

Four operations. When something changes the value from outside, the caller
derives the current value, applies the change, and stores the pair `write`
hands back: the new value and the increment of now. Nothing is ever iterated.
A thousand tanks healing costs exactly what one tank healing costs, which is
nothing until it is looked at.

Every periodic effect in the game takes this shape and no other: healing per
unit kind, reload per weapon kind, the shield's recharge, the roster's
recovery, the cloud's rounds, the claim, the plane's launch, the discovery
broadcast. Each is a row in a **table of counters** kept in the world as flat
arrays — period, increment, next tick — indexed by a name, and adding an effect
is adding a row. The intervals live in the catalogue in seconds and are
converted once at load.

The derivation is a pure function of four integers, which is why the vision
called it perfect for the handheld's runtime: a box may be exactly this and
nothing more.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Every periodic effect, as a counter and a pair of integers." timers`.
2. Write `counter(period)` returning the three integers, refusing a period
   below one.
3. Write `advance(counter, tick)`: while the tick has reached the next firing,
   raise the increment and push the next firing on by the period.
4. Write `read(value, written_at, counter, cap)` exactly as above, and
   `write(counter, value)` returning the pair.
5. Add the counter group to the world's layout and the table of named
   counters, and add the advance of every counter to the front of the tick.
6. Fill the companion with the four-operation derivation written out, because
   it is the one thing every later issue will want to read again.

## What happened

- **A write holds the value under the cap but not above zero.** A health that
  goes below zero is the die pass's question, and clamping it here would hide an
  overkill the bones may want to know about.
- **Advancing twice to one tick is harmless**, so a system run alone by a test
  (the claim pass) can bring its own counter up without disturbing the tick.
- **`ticks_of(seconds, rate)` is here** and refuses a duration under half a
  tick instead of lifting it to one: an effect every zero ticks is a catalogue
  mistake.
- **Counters are tables reached by name**, `world.claim` and later
  `world.heal.tank`, because that is how the tests read them; the layout's
  `COUNTERS` is the one list of them, in the order the tick and the hash walk.
- A counter's first firing is at its period, so during tick `5 * period` it
  fires the fifth time. The companion writes this out.

## Related documents and tools

- [The tick and the timers](../../docs/003-the-tick-and-the-timers.md)
- [The handheld](../../docs/012-the-handheld.md)
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)
- `strategems/patterns-that-keep-working`, which records this shape as a pattern

## Still open

Nothing beyond the questions in the table. One thing to watch: an effect whose
value can go *down* on its own — a shield draining, say — is not this shape,
and the first time one is wanted is the first time this design has met
something it did not anticipate.
