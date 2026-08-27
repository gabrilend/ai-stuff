# 106-controls

Three dials and a handful of verbs. A command is
*(which units) × (which way) × (how far) × (what to do)*, and the first three are
**state that keys change** rather than arguments a key carries.

## One keyboard genuinely cannot drive four bodies

The three obvious answers — drive one and have three follow, order all four at
once, drive one at a time — are each half of what somebody wants. The dial is all
of it: point at all four and say *go*, point at one and say *stay*, point
north-east-far and say *reach*.

## Where it comes from

A real control scheme, built by the person who asked for this project, for
commanding a squad in an action game. It is a modal state machine made of bind
files — loading a different file changes what every key does — holding which
group, which of eight compass directions, and one of three distances. Keys like
`q e t f` apply verbs to whatever the dials point at; keys like `6789 0` and
`U I O H` turn them.

And every key that turns a dial prints a small diagram of where they now point.

## Why the arithmetic is in C

The dials belong to a view and the server must never hear about them. But the
step from three dial positions to a point in the world is **arithmetic**, and
arithmetic in C is arithmetic that can be checked without a browser, forty times,
in a millisecond.

Both views take the compass from here — the bridge generates it into `tables.js`
from this table — so they cannot drift apart about what north-east means. What
north-east means is a number, and two copies of a number drift.

## The dials

| Dial | Positions | Wraps? |
| --- | --- | --- |
| aim | eight compass points, clockwise from north | yes |
| reach | close (3 m), near (8 m), far (16 m) | **no** |
| choosing | the whole party, or one of them | it cycles |

A direction **wraps**, because a control you can walk off the end of needs a
boundary check every time it is read.

A distance **does not**. Distance is a line rather than a circle, and somebody
pressing *further* three times expects the far end rather than to be back where
they started.

The choice **cycles**: everybody, then each member in turn, then everybody again.
One key. The whole party is a *position on the same dial* rather than a separate
mode, which is what makes pointing at all four as few keystrokes as pointing at
one.

## A diagonal does not travel further

The diagonal unit is 724 of 1024 — 0.7071 — rather than a full unit on both axes.
A diagonal step that moved a full unit each way would travel forty per cent
further for the same key, and a person would feel it without being able to say
why.

There is a test that checks every direction covers the same distance, compared as
squares so that no square root is needed and no floating point enters a project
that has banned it.

## The distances are rooms, not doublings

Three metres is inside the room with you. Eight is across it. Sixteen is the far
wall. Chosen by what a tabletop distance means, because a person aiming a squad
is thinking in rooms.

## The diagram

Seven characters square, with you in the middle. Odd on both axes so there *is* a
middle; seven because the far reach needs three cells of line to look further
than the near one.

```
       
     X 
    /  
   o   
       
       
       
```

**Drawn from the dial rather than from a copy of it**, so it cannot disagree with
the state it is showing. That is the third instance of *make the state its own
display* in this project, arriving from a third direction — see
[the strategems](../strategems/patterns-that-keep-working).

## The server never learns any of this

A view resolves the dials into a point and sends an ordinary `order-move`, which
is a verb the server has had since phase 3. A server that knew what "north-east,
far" meant would be a server with an opinion about how people play.

It also means a second view can grow the same dial without a protocol change,
which is the phase 11 claim being cashed again.

## Functions

| Function | Does |
| --- | --- |
| `dial_init` | north, near, everybody |
| `dial_turn_aim` / `dial_turn_reach` | turn one dial; the first wraps, the second clamps |
| `dial_cycle_choice` | everybody → each → everybody |
| `dial_choose_whole_party` / `dial_choose_one` | jump straight to a position |
| `dial_resolve` | three positions and a body's place → a point in the world |
| `reach_in_metres` | so a readout can say the number |
| `aim_name` / `reach_name` / `act_name` | the words |
| `dial_diagram` | seven lines, drawn from the dial |
| `dial_sentence` | one line saying where every dial points |

## Related

- [107-test-controls](107-test-controls.c)
- [067-view.js](067-view.js) — the browser's dial, taking its compass from here
- issues [1204](../issues/completed/1204-the-controls-are-a-dial-you-can-see.md),
  [1205](../issues/completed/1205-the-state-is-drawn-back-to-you.md)
