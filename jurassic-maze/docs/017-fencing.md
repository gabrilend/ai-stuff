# Fencing

Two little guys with swords, in a corridor, taking turns. A duel is a state
machine with two bodies in it, and it ends.

## A duel is a thing, not a state of two bodies

When two fencers of opposing teams meet, a **duel** is created: a small record
with two body ids, their generations, a clock, and whose turn it is. Both bodies
point at it.

It is a separate record rather than fields on each body for one reason: a duel
has to end, and ending it has to be one action. Two bodies each holding "I am
fighting that one" can disagree — one dies, the other is left swinging at
nothing — and every version of fixing that is a check performed in two places
that must stay in step. One record, with two references into it, cannot get out
of step with itself.

## The exchange

The duel holds a clock. Every `exchange_seconds`, one blow is thrown, and the
throwing is:

1. The attacker draws from the `duel` stream against its own `skill` and the
   defender's `parry`.
2. A hit **buffers** damage. It does not apply it. See
   [the tick](010-the-tick.md) — buffering is what makes a mutual kill possible
   instead of making it a function of array order.
3. Turn passes to the other body.

Both fencers stand still while the duel runs, facing each other. Their
locomotion does not advance; the duel owns them. This is the simplest thing that
looks like fencing from an isometric camera two hundred cells away, and the
alternative — real footwork, lunges, retreats — is a great deal of machinery for
detail that is a handful of pixels tall.

## How it ends

| Ending | What happens to the survivor |
| --- | --- |
| one body's health reaches zero | it dies; the other is released to decide again |
| both reach zero in the same tick | both die. Buffered damage is why this is possible. |
| the duel exceeds `stalemate_seconds` | both released, both given `flee` for a short time so they do not immediately re-engage |
| one body's partner fails its generation check | the duel is dissolved and the survivor released |

The stalemate timer exists because two evenly matched fencers with high parry can
otherwise stand in a corridor exchanging misses until the machine is turned off,
and because the camera watching them would have nothing to swap to under
`auto swap` — the duel never ends, so the verdict never fires. A rule about
combat, added for a reason about watching.

## Re-engaging, and the question underneath it

When a duel ends and a fencer is released, it may find another opponent
immediately. Whether it *should* is
[an open question](026-open-questions.md) and it is the same open question that
appears in [the camera](008-the-camera-and-what-it-watches.md):

> *"for the fencing guys, they should be able to swap to a different target ...
> to continue the watching experience"*

If that sentence is about the fencer, then a released fencer looks for a new
opponent nearby and the fight rolls on — a melee rather than a series of duels,
and the camera can stay where it is.

If it is about the camera, then a released fencer wanders off as normal and the
camera goes and finds somebody else who is fighting.

Both are small. Both are worth having. Neither is implemented on a guess, and
the `flee` interval above is written as a knob rather than a constant precisely
so that setting it to zero turns one behaviour into the other without a rewrite.

## Teams

`team` is a small integer on the body and zero means unaffiliated. Two fencers
duel when their teams differ and neither is zero.

Teams are also what the camera's `same team only` setting reads, which means a
change to how teams are assigned changes what the camera does. That coupling is
recorded here because it is the sort of thing that is obvious while writing it
and baffling six months later.

## Related documents and tools

- [Two bodies meeting](016-two-bodies-meeting.md) — where a duel begins
- [The camera and what it watches](008-the-camera-and-what-it-watches.md) — what happens when it ends
- [The tick](010-the-tick.md) — buffered damage and the resolve pass
