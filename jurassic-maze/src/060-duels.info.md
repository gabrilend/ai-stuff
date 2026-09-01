# 060-duels

A duel is a record with two bodies in it, and it ends.

Read this page rather than the source, and read
[fencing](../docs/017-fencing.md) before either.

## Why a record

A duel has to end, and **ending it has to be one action**. Two bodies each
holding "I am fighting that one" can disagree — one dies and the other is left
swinging at nothing — and every version of fixing that is a check performed in
two places that must stay in step. One record with two references into it cannot
get out of step with itself.

It is a second flat-array store with a free list, exactly like the body store, so
the generation trick that catches a stale id works here without being invented
twice.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(BodyStore, Walking, Creatures)` | | at world creation |
| `new_store(capacity)` | | the duel store |
| `begin(world, a, b)` | | a duel, or nil if the store is full |
| `meets(world, bodies, a, b)` | | the meet-table entry for two fencers |
| `pass(world, dt)` | | one tick of every live duel. Buffers damage; applies none. |
| `resolve(world, dt)` | | applies it, all at once, and carries out the deaths |
| `finish(world, d, ending)` | | one action |
| `KILLED`, `MUTUAL`, `STALEMATE`, `DISSOLVED` | | the endings, by name |

## Both of them strike

Every `exchange_seconds`, **both** fencers throw a blow. Taking turns was written
first and it makes the buffering decorative: if only one blow is thrown at a
time, two fencers can never kill each other in one tick, and the case the whole
arrangement exists for cannot arise. It also reads worse — a clash is two people
swinging, not two people politely alternating.

With them both striking, about one duel in eight ends with both of them falling.

## Damage is buffered and applied elsewhere

A hit adds to `incoming_damage`. Nothing is subtracted from anybody's health
until the `resolve` pass, which does all of it and then carries out every death
before anything reads the bodies again.

Applying as dealt means whichever body the pass reached first kills the other and
survives, so the outcome of every duel is decided by an array index — which
changes whenever any unrelated body dies and its slot is recycled.
`tests/061-duels.lua` runs the same mutual kill with the ids in both orders and
requires the same answer.

## The four endings

| | |
| --- | --- |
| one of them fell | the survivor is released |
| both of them fell | the case buffering exists for |
| neither could land a blow | the stalemate clock |
| one of them is no longer there | the generation check |

The **stalemate clock** is a rule about combat added for a reason about watching.
Two evenly matched fencers with a high parry stand in a corridor exchanging
misses until the machine is turned off — and a camera watching them under "swap
on its own" has nothing to swap to, because the duel never ends and the verdict
never fires.

`disengage_seconds` is a knob and not a constant on purpose. **Zero turns a
series of duels into a melee**, which is the other reading of
[open question 1](../docs/026-open-questions.md), and it is one number either
way. There is a test for both.

## Who came off worse

Damage taken is accumulated on the duel rather than derived from health
afterwards, because after a stalemate both walk away and the record of who lost
would be gone with it. The camera's "stay with the loser" reads it.

When the loser *died* there is nobody to stay with, and the camera moves whatever
the setting says. That is not a compromise — it is what the words mean once one
of the two is not there.
