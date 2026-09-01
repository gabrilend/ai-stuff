# 502 — Damage Is Buffered, Then Applied

| | |
| --- | --- |
| Phase | 5 — The Fencing |
| Blocked by | 302, 501 |
| Blocks | 503 |
| Reads | [the tick](../../docs/010-the-tick.md), [fencing](../../docs/017-fencing.md) |
| Open questions | none |

## Current behavior

`incoming_damage` on the body, added to by the duel pass and consumed by the
resolve pass, which applies all of it and then carries out every death before
anything reads the bodies again.

**Both fencers strike each exchange**, which this issue did not say and which the
buffering needs. Taking turns makes the buffering decorative: if only one blow is
thrown at a time, two fencers can never kill each other in one tick and the case
the whole arrangement exists for cannot arise. With both striking, about one duel
in eight ends with both of them falling.

`tests/061-duels.lua` runs the same forced mutual kill with the ids in both
orders and requires the same answer, which is the only test that can catch the
array-order failure this issue is about.

## Intended behavior

Every `exchange_seconds`, one blow is thrown: a draw from the `duel` stream
against the attacker's `skill` and the defender's `parry`. A hit **buffers**
damage into a per-body accumulator. It does not apply it.

Application happens once, for everybody, in the `resolve` pass.

The reason is exact: **two fencers who strike each other fatally in the same tick
must both die.** If damage applied immediately, whichever body was stored first
would kill the other and survive, and the outcome of every duel would be decided
by an array index — which changes whenever any unrelated body dies and its slot
is recycled.

The buffer is one array of doubles in the body store, zeroed by the resolve pass
after it applies. Zeroing after rather than before means an accumulator that was
never applied is visible as a non-zero value at the start of a tick, which is a
test worth having.

## Suggested implementation steps

1. Add the `incoming_damage` array and zero it on spawn.
2. Write the exchange in the duel's tick, buffering only.
3. Write the resolve pass: apply, detect zero-crossings, mark deaths, zero the
   buffer.
4. Deaths are marked in resolve and carried out in resolve, before any pass that
   reads bodies again — a body that is dead for part of a tick and alive for the
   rest is a body two passes disagree about.
5. Test: two fencers with identical stats and enough damage to kill, forced to
   strike on the same tick, both die. Run it with their ids in both orders and
   assert the outcome is the same.

## Related documents and tools

- [The tick](../../docs/010-the-tick.md)
- [Fencing](../../docs/017-fencing.md)
