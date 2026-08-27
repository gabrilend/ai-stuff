# 060-the-formation-sandbox

A field with nothing on it but two formations.

## Running it

```
luajit tests/060-the-formation-sandbox.lua
```

Prints eleven results and writes a full trace to `tmp/shared-memory/formation-sandbox.log`.

## Why it is separate from the invariants

Asking "does a rank stay a rank round a bend" through a whole match means the answer
arrives buried in everything else — two teams, three lanes, a spawn cadence, a chest,
an economy, a phase clock, towers shooting — and it means a change to any of those
can turn it red for reasons that have nothing to do with formations. **A test whose
failure does not tell you where to look is a test that gets ignored.**

So this brings in only what it measures, and it **does not run the tick.** It runs
the four passes under test, by hand, in order:

```
index  ->  plan  ->  think  ->  (engage)
```

No spawner, no chest, no commanders, no phases are standing while these numbers are
taken. The waves are built directly rather than through the spawner, which reaches
for a commander, a bounty, a chest and a cadence — none of which this is about.

The lane comes from `lane_from_polyline`, which was added for this: a test that wants
a sine wave should be able to ask for a sine wave.

## What it measures

**The formation's circle.** Every body stands inside the circle whose edges touch the
left and right of the line as it walks, and on a straight every body is exactly in
its file with no lag.

**A left turn.** The claim under test is that the outer end of the line has more
ground to cover and must hurry, while the inner end must give way — out of one
budget, so the line stays a line. Measured over the 291 ticks inside the bend: the
outer body covers **321 paces to the inner's 290**, is hurried to a multiplier of
**1.0043** while the inner gives way to **0.9972**, and the worst any body falls
behind its place through the whole turn is **1.7 paces.**

**A sine wave.** The same, along a lane that turns one way and then the other with no
straight to recover in, so a rule that only worked in one direction would show. Worst
lag stays under 6 paces, nobody leaves their file at all, and the budget still
balances while the curvature keeps changing sign.

**Two formations meeting.** They walk at each other, meet front to front in the
middle, and one of them is left standing.

## The bug it was written for

Holding a formation in lane coordinates makes a turn *free*: every body in a rank
shares one distance-along, so going round a bend costs each of them the same number
and their world positions simply follow the curve.

Which means the body on the **outside** was covering more world ground for the same
lane distance — moving faster than its own speed, with nothing to notice. Movement
is now measured after the step and scaled back if it went too far, so the outer body
genuinely falls behind and the cohesion budget has something to correct.

The test does not merely confirm the fix; it is the reason the fix exists.

## The one coupling it could not avoid

The formation reaches the spatial grid, because a wave stops when something hostile
is near its front and "near" is a query. That is a real dependency and the log names
it at the bottom, on the principle that a thing a test needs and should not is worth
knowing about.
