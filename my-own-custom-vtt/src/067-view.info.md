# 066-view.html and 067-view.js

State in, a moving picture out. Served by the bridge from localhost.

## It holds no truth and is never trusted

Everything drawn arrived from the server, which already decided what this person
may know **by not sending anything else**. Modifying this file cannot reveal an
ambush, because it was never told about one — and that is the entire reason the
geometry runs on the host's machine rather than here, where it would be far more
convenient and completely worthless.

## An update is the whole picture

Each one replaces what was held rather than amending it. A dropped update costs a
beat of freshness and nothing else, and a rollback desynchronises nothing. A
half-arrived update is never swapped in — `OP_END` is what says it is complete.

## Interpolation, and the part that is not standard

The world beats twenty times a second and a browser draws sixty, so the view holds
the two most recent states and draws between them, one beat behind live.

**A body that appears or disappears is not interpolated from nowhere.** Bodies
arrive and leave constantly here, because the filter sends only what is currently
visible. A goblin stepping out from behind a pillar is not moving quickly — it was
absent and is now present, and interpolating it from an old position would slide
it out of a wall.

That is a direct consequence of sight being a security boundary, and would
otherwise be discovered as "why do goblins slide out of walls".

Facing takes the **short way round**, or a body turning past due east spins all
the way about.

## Prediction

The one place this file shows something the server has not confirmed — and not an
exception to the trust rule, because predicting where your own character is
reveals nothing you did not already know: you pressed the key.

Only a commanded body. Always overwritten by the server's answer. Eased toward
the truth, **with a cap** — past a few metres it jumps, because a large
disagreement means the prediction was wrong about something structural like a
wall, and easing across a room looks worse than a snap.

`OP_RECALL` discards it outright.

## Three layers, painted in order of certainty

| Layer | Looks like |
| --- | --- |
| Never seen | Nothing. Not black — **absent**. |
| Remembered | The floor plan, desaturated and still. |
| Visible | Lit, clipped to the polygon, and the only layer with bodies. |

The polygon is the one the server computed to decide what it was allowed to send.
**The geometry that made the fog secure is the geometry that makes it look right.**

## Keys are a state, not an event

A drive command goes out when the set of held keys **changes**, and a stop when
the last lifts — not one per frame. That works with the server's standing-order
model rather than against it, means a dropped frame does not drop a step, and
bounds the command rate by fingers rather than by a monitor.

Two keys held is **one** direction computed from both, not two commands fighting.

## Screen to world lives in one function

The only arithmetic here the server will act on. Written twice it would be
written differently twice, and the symptom is clicks landing a metre from where
somebody pointed.

**Commands carry metres.** The readout speaks feet, rounded, and never converts
back — two clients rounding differently would disagree about where somebody
stood.

## Refusals appear where the person is looking

Not in a console. A refusal nobody sees is a silent drop with extra steps.

## The slot table comes from the bridge

`/tables.js`, generated from the C header at startup. Not written here a second
time.
