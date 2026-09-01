# Idling And Being Idle Together

The vision asks for "little guys wandering about with idle animations". The
wandering is [the walk](014-walking-the-surface-graph.md). This is the standing
still, which is the harder half, because standing still is where a simulation
either looks alive or looks paused.

## An idle is a state with a clock, not an animation

There is no animation system here and there is not going to be one. An idle is a
row in a table: a name, a duration drawn from a range, and a small amount of
motion the renderer applies while it runs.

| Idle | Duration | What the renderer does |
| --- | --- | --- |
| `breathe` | long | the body's drawn height oscillates by a fraction of a layer |
| `look_around` | medium | `facing` rotates one quarter turn at a time, pausing between |
| `stretch` | short | the body leans back, then returns |
| `crouch` | short | the body's drawn height drops and returns |
| `scratch` | short | a small horizontal jitter |
| `sit` | very long | the body's drawn height drops and stays down until the idle ends |

The simulation's whole involvement is: which row, and how much of its clock is
left. Everything visible about it is arithmetic in the renderer driven by the
fraction of that clock elapsed. So a body idling costs one timer decrement per
tick, which is what lets there be a great many of them.

`breathe` is the default and the one that matters. A body that is genuinely
motionless reads as a bug — the eye assumes something crashed. A body whose
height moves by a twentieth of a layer on a slow cycle reads as alive, and
nobody notices why.

## Choosing which one

From the `idle` stream, weighted per creature kind. A creature table row carries
a weight per idle, so a nervous little guy scratches and looks around, and a
sunning dinosaur sits.

The weights are numbers in the table and not in this document, which is the rule
everywhere: [balance-updates](balance-updates.md) records why one was changed,
the table holds what it is now.

## Being idle together

The part that is not just one body with a timer.

When two idling bodies are in adjacent cells and have been idle for longer than
`notice_seconds`, they may enter a **shared idle**: both are given the same idle
row, the same clock, and each is set to face the other. They stand together and
do the same thing at the same time, and then they both stop.

That is the entire mechanism, and it is enough to produce the thing that reads as
two people having a conversation. Nobody is having a conversation. There is no
dialogue, no relationship, and no memory of it afterwards. There are two timers
that were set to the same value and two `facing` fields that were pointed at each
other.

A shared idle is entered through [the meet pass](016-two-bodies-meeting.md) and
not by either body deciding on its own, because two bodies each independently
deciding to share would produce the case where one shares and the other has
already walked off — leaving a body facing an empty cell, doing a synchronised
animation alone. That is funny once and then it is a bug.

## Interrupting

Any intent that is not `idle` cancels the idle immediately, including the shared
one, and cancelling a shared idle cancels it for **both** bodies. A body left in
a shared idle whose partner has gone is the same empty-cell case, arrived at from
the other direction.

The generation check does the work here: the partner id is stored with the
partner's generation, and a shared idle whose partner fails that check ends the
same tick. See [a body and what it carries](011-a-body-and-what-it-carries.md).

## Related documents and tools

- [Two bodies meeting](016-two-bodies-meeting.md) — where a shared idle is entered
- [Walking the surface graph](014-walking-the-surface-graph.md) — the intents an idle competes with
