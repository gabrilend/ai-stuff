# 032-timers

Every periodic effect, as a counter and a pair of integers.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The one shape every periodic thing in the game takes. A **counter** is a global
countdown that never walks anything; a thing subject to the effect stores **two
integers**, a value and the increment it was written at, and its current value
is derived when asked.

The derivation, written out because every later issue will want it again:

1. `counter.increment` is how many times the counter has fired.
2. The thing stores `value` and `written_at`.
3. `current = value + (counter.increment - written_at)`.
4. `current = min(current, cap)`.

A change from outside (a shell lands): derive `current`, add the change, hold it
to the cap, and store the pair `(current, counter.increment)`. Nothing is ever
iterated, so a thousand tanks healing costs what one does.

A counter fires when the tick reaches its next firing; the first firing is at
its period. So after the ticks 0 to `5 * period - 1` have run it has fired four
times, and during tick `5 * period` it fires the fifth.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `counter(period)` | a whole number of ticks, at least one | `{period, increment = 0, next = period}` |
| `advance(counter, tick)` | a counter; a tick | nothing; raises the increment once for every firing the tick has reached. Asking twice for one tick changes nothing the second time. |
| `read(value, written_at, counter, cap)` | the pair, the counter, the cap | the current value |
| `write(value, written_at, counter, cap, change)` | the pair, the counter, the cap, the change | the new value and the increment of now. Not held above zero: a health below zero is the die pass's business. |
| `ticks_of(seconds, ticks_per_second)` | positive seconds; a whole rate | whole ticks, rounded to the nearest; refuses a duration under half a tick rather than lifting it to one |

## Data structures it owns

The counter: `period`, `increment` and `next`, three whole numbers. A counter in
the world may carry more whole numbers beside them -- the claim's
`increments_to_claim` -- copied from the rules when it is made.
