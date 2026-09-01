# 060-duels

A duel is a record with two bodies in it, and it ends. **Any** two bodies of
opposing sides that can hurt each other — not only fencers.

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

## It is not only for fencers

It was, and generalising it is what turned the delve from a design into a running
mode in an afternoon. A human with a torch against a vine, a dinosaur with a
hammer against a wooden machine, a golem against anything: all of them are two
bodies exchanging blows and buffering the damage, which already existed, already
worked and already had tests.

Two things had to change for that.

**Each side uses its own numbers.** A duel between two fencers is symmetric and
it did not matter; a duel between a human and a stone golem is not, and reading
both sides' stats off whichever body happened to be stored first would give the
golem a human's skill depending only on array order. The faster of the two sets
the pace, so a quick opponent is not slowed down by a heavy one.

**Damage is multiplied by the defender's `resist` for the attacker's weapon.**
Fire does nothing at all to stone and ruins a plant. The multipliers live in the
creature table; this file only looks them up.

A held body cannot swing. Being entangled is the one thing in the delve that
stops a fight rather than deciding it.

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

`disengage_seconds` is **zero** for a fencer, which makes a series of duels into
a melee: a released fighter re-engages immediately and the fight rolls on. That
was open question 1 and it is answered — the sentence was about the fencers, not
about the camera.

It is still a knob, and above zero it is the other behaviour with the camera
going looking between fights. Both have tests, which is why it stays a knob.

Each side keeps away for **its own** interval, so a mode where one kind
re-engages and another does not is a table edit.

## Who came off worse

Damage taken is accumulated on the duel rather than derived from health
afterwards, because after a stalemate both walk away and the record of who lost
would be gone with it. The camera's "stay with the loser" reads it.

When the loser *died* there is nobody to stay with, and the camera moves whatever
the setting says. That is not a compromise — it is what the words mean once one
of the two is not there.
