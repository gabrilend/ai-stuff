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

Every run writes the numbers into a log. They are **not quoted here** — they were,
and then the bodies were spread further apart and the paragraph went on describing a
formation the game had stopped building. Run it.

**The formation's circle.** Every body stands inside the circle whose edges touch the
left and right of the line as it walks, and on a straight every body is exactly in
its file with no lag.

Measured **from the formation's own centre, not the road's.** A wave sits off the
centre line of its road for two reasons — it has been shifted to stand abreast of two
others during a challenge, and it is wandering toward a waypoint — and neither of
those is the line coming apart. Against the road, a wave that has drifted six paces
looks exactly like a wave whose flank has been pushed six paces out of the rank, and
those are opposite events.

**A left turn.** The claim under test is that the outer end of the line has more
ground to cover and must hurry, while the inner end must give way — out of one
budget, so the line stays a line.

**A sine wave.** The same, along a lane that turns one way and then the other with no
straight to recover in, so a rule that only worked in one direction would show.

**The wander.** A wave on a **straight** road must not walk a straight line. This is
the one property that can only be measured on ground with no curve in it: on a bend,
a formation moving sideways is indistinguishable from a formation following the road.

Two opposite failures are watched for. No wander at all means the waypoints are not
being read and the feature is decoration. Wander past the shoulder means the clamp is
wrong and part of a rank is in the ditch — which is why the offset is bounded by the
road's half-width **less the formation's radius** rather than by the half-width.

**Two formations meeting.** They walk at each other, meet front to front in the
middle, and one of them is left standing.

## Where a test wave gets put down

Further along the road than the formation is deep, and the sandbox **refuses out
loud** if it is not.

A body's place sits a fixed distance behind its wave's front, so a wave set down near
the start of a road has its rear ranks wanting to stand behind the beginning of it —
where there is no ground. They are clamped to the start and read as hopelessly out of
position while standing as far back as the world allows. Correct, harmless, and over
within a hundred paces.

It is also invisible, and it was quietly inside two measurements of how well a
formation turns, with the tolerances sitting just above it until the ranks were
spread out. The number that decides how deep a formation is lives in the formation
module and can be changed there by somebody who has never opened this file, so the
refusal is loud rather than a nudge.

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
