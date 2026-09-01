# 008 — The Day and the Curve

How time works, why it never moves on its own, and the small horizontal object
that lets you sweep through somebody's day.

## The hour is a global axis

One number, shared. Not a parameter belonging to any filter.

This matters because at least two unrelated things read it: the shade filter,
which swings the great tree's shadow across the north-west district, and **every
person's whereabouts**, which is a function of the hour rather than a stored
position. A value two independent systems both consult belongs to neither, so the
hour sits above all of them, at the top of [the tome](007-the-tome.md).

Its control being one thing has a consequence worth having: drag the hour and the
shadow swings while everyone slides along their own day, in the same motion. One
control, several truths moving together.

## The time is only ever now

The clock is never wound forward. **The world does not advance by itself**, and
it does not advance when you sweep the hour. It advances only when you make a
move, or push go on moves you queued.

Sweeping the hour is not time travel — it is **consulting your model of the
city**. You are looking at what you understand people to do, in order to plan
your next move. Shadows at three in the afternoon while it is nine in the morning
are not a prediction the game is making; they are what *you believe* would be
true then.

This is why nothing on screen ever needs marking as hypothetical. A live map that
could be scrubbed away from the present would need a loud, unmissable indication
that you were looking at a moment that isn't real, or every reading on it would
become untrustworthy in a way that is very hard to notice. This design does not
have that problem, because none of it was ever a live camera. See
[the governing idea](001-what-this-game-is.md).

## Where a person is, is a function

There is an equation that answers where somebody is, given the hour. Feed it a
time and it returns either a **block**, or — when the hour lands inside something
they are doing — a **description of the doing**.

Because it returns a block rather than a coordinate, nothing new needs drawing on
the map. The existing glow does the work: the block the equation names lights up.
The map's four marks stay four. See [the map surface](002-the-map-surface.md).

When it returns a description instead, that is words, so it appears in the tome's
text pane and nowhere else.

## The time-curve

A person's day, plotted, in a container roughly **225 by 30 pixels** — about twice
a scrollbar's width and a quarter as long — always horizontal.

The vertical axis is **activity**. High means busy, low means resting. Busy is
busy regardless of kind: patrolling a quarter, hauling grain sacks, and bent over
old books all read as high. Rest is not idleness in this game; people need it,
and a curve pinned high all day is telling you something about that person.

The dimensions set what it can honestly say. Across, a whole day in 225 pixels is
about nine pixels an hour — plenty for sweeping. Up, thirty pixels gives roughly
five activity levels a person can actually distinguish. **So the curve is a
shape, not a measurement**: you are meant to see the two humps and the trough
between them, not read a number off it. That is the right resolution for what it
is.

### Sweeping it moves the whole world

Dragging along a curve drives the global hour, so the shade swings and everyone
else slides along their own day as you go. The city becomes one thing you can
play back and forth by hand.

Because the hour can now be driven from several places, an accidental mouse-over
must not throw the world about — hovering and dragging have to be distinguishable.

### You can only read people you know

Time-curves are legible for **your people, and people you have come to know**.
Everyone else has a day you cannot see, because you cannot model a stranger.

This makes acquaintance directly visible as a stack of days you are permitted to
look at. Early on there is one curve, your own. Later the tome holds a dozen, and
sweeping across them shows the city's morning happening.

### A few pinned, the rest on demand

You pin the handful of people you are actually thinking about into a small stack;
anyone else's curve opens singly when you ask for it. Pinning is a thing to
manage, and forgetting to unpin leaves stale people in view — that is the cost,
and it is smaller than either alternative, since one-at-a-time makes comparison
impossible and all-at-once becomes fifteen hundred pixels of curves at fifty
acquaintances.

## Datapath summary

```
              the hour  (one number, global)
                  │
      ┌───────────┼────────────────┐
      │           │                │
      ▼           ▼                ▼
  the shade   whereabouts     every other
   filter      equation      time-dependent
      │           │            reading
      │           ├──▶ a block ──▶ the glow, on the map
      │           └──▶ a doing  ──▶ words, in the tome
      ▼
  hatching, on the map


  a time-curve  ──swept──▶  sets the hour  ──▶  all of the above
       ▲
       │ readable only for
       │
  your people, and people you have come to know
```

## Related documents

- [What this game is](001-what-this-game-is.md) — the model-not-camera idea
- [The tome](007-the-tome.md) — where the hour and the curves live
- [The map surface](002-the-map-surface.md) — the glow the curve borrows
- [Open questions](013-open-questions.md)
