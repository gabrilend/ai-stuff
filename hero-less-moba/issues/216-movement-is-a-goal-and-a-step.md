# 216 — Movement Is a Goal and a Step

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 202, 203, 211c, 214, 215 |
| Blocks | 212, 602 |
| Reads | [standing off and falling back](../docs/022-standing-off-and-falling-back.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | M1, M2, M3, M4 |

**This is the umbrella.** The work is in three sub-issues, listed at the bottom, and they
should be read in order.

## Current behavior

**Nine different things move a body, and each of them moves it a different way.**

Marching in a formation, closing on an enemy, a guard wandering, a guard walking home, a
guard chasing something inside its leash, a hero walking its lane alone, a hero crossing a
connector, a body with a reach giving ground, and a hero walking off the map during a
calm. Every one of those computes a distance, applies its own idea of speed, and writes a
position. Some go through the rule that keeps bodies out of each other and some do not.
Some are capped by how far a body may move in the world and some are not.

The nine are not nine behaviours sitting in a table. They are a run of early returns
inside one function in the brain, and the order of those returns is the policy — which
means the policy is only readable by reading the function.

Two coordinate systems run underneath, and which one is authoritative depends on the
body. A body on a lane keeps how far along and how far across; its world position is
derived. A guard keeps a node, a progress along an edge, and an offset in world paces.
**Writing a world position into a lane body does nothing** — the next move re-derives it —
which is a mistake this project has made twice, in two different rules, and found both
times by watching a correction fire every tick and achieve nothing.

Speed is a multiplier on a body's stated pace, decided by how far out of place it is:
seven tenths if it has got ahead, full pace otherwise. Nothing goes faster than that, on
purpose, and the reasoning is written down: a line dresses itself by the inside of a turn
slowing rather than the outside sprinting.

## Intended behavior

**Everything that moves does it the same way, and what differs between them is one row in
a table.**

Two layers, and only the lower one knows that other bodies exist.

### Where it wants to go

A **goal**: a point in the world, and a **pace** — relax, normal or hurry. It is placed
fresh every tick by the body's **movement pattern**, and it is allowed to be a very long
way off. A formation's place for a body can be ninety paces away. An enemy can be across
the lane.

**A pattern is not allowed to care about other bodies being in the way.** That is the
whole separation of the two layers: a pattern answers *where do I want to be*, and
anything about what is standing between here and there is somebody else's question.

### Where it will actually stand

A **step**: the point this body will occupy at the end of this tick. Derived from the goal
by two rules, in order, and both belong to the lower layer:

1. **Capped.** No further from where the body is standing than its pace allows, measured
   **in the world**. This is where the three speeds are actually spent.
2. **Cleared.** If the step would land within `self.radius + other.radius` of any body, it
   is moved out to the nearest point that is not — the rule that already exists, asked
   about the step exactly as it is asked today.

Then the body is put on that point, through whichever representation its position actually
lives in. One place converts, rather than nine.

### Why the cap subsumes a correction that exists today

Holding a formation in lane coordinates makes a turn free: every body in a rank shares one
distance-along, so the lane carries the line round the bend. But a body on the **outside**
of that bend covers more ground in the world, and today that is corrected afterwards by
measuring how far it actually went and scaling the step back over three passes.

With the step placed as a world point capped at a world distance, there is nothing to
correct. The outer body's step is short of its goal because the cap is a world distance,
and it falls behind its place honestly rather than being caught cheating and rolled back.

### The patterns become a table

| Pattern | Places its goal at | Pace |
| --- | --- | --- |
| `march` | its place in its wave's formation | relax, normal or hurry by how far out of place it is |
| `charge` | its target | hurry |
| `stand_off` | back along its own lane | relax |
| `orbit` | out along its own rank, or in toward the enemy's middle | normal |
| `patrol` | a neighbour node inside the leash | relax |
| `leash` | the tower it guards | hurry |
| `chase` | its target, inside the leash | hurry |
| `lane_walk` | straight down its lane | normal |
| `cross` | along the connector it is on | normal |
| `withdraw` | back down its lane, off the map | hurry |
| `hold` | where it is standing | — |

Adding a way to move becomes adding a row, next to the rest, rather than another early
return in the middle of a function whose order is the policy.

**The brain still chooses**, and that does not change: the state table says what a body is
doing, and what it is doing names its pattern. What changes is that having chosen, every
body is moved by one mechanism.

## Suggested implementation steps

**In the sub-issues, in this order.** The layers have to exist before patterns can be
written against them, and the patterns have to exist before the paces mean anything.

## The sub-issues

| | |
| --- | --- |
| [216a](216a-a-goal-and-a-step.md) | A goal, a step, and one thing that moves a body |
| [216b](216b-every-way-of-moving-is-a-row.md) | Every way of moving is a row in a table |
| [216c](216c-three-paces-and-hurry-is-faster.md) | Three paces, and hurry is faster than marching |
| [216d](216d-a-guard-is-still-an-edge-walker.md) | A guard is still an edge walker |

## Open questions

**M1. Does the separation pass survive this?**
Under the new arrangement a body lands exactly on a step that was cleared before it moved,
so it arguably cannot land inside anybody and the pass is redundant. Two holes in that
argument: a body that is *placed* rather than stepped — a spawner, a hero bought and
dropped onto a wave — never goes through a step at all, and the whole guarantee then rests
on an argument rather than a measurement. **The pass is kept**, because it is the only
reason "no two bodies overlap at any tick of a whole match" is a measured fact, and
because every version of "the step was clear so the body must be" has been wrong once
already today. Retiring it would make matches about one and a half times faster.

**M2. Is a goal in world coordinates the right currency?**
It makes guards and lane bodies the same kind of thing for the first time, which is most
of the modularity. The risk is the opposite of the one lane coordinates were chosen for: a
pattern that computes a world point directly, rather than computing lane coordinates and
converting, would lose the property that a rank curves round a bend for free. The marching
pattern must go on working in lane coordinates and converting at the end, and nothing
enforces that.

**M3. What does `hold` do about being shoved?**
A body standing still has a goal on its own feet. It is still separated out of anybody who
walks into it, so it drifts. Whether a body holding ground should return to where it was
holding, or accept where it has been pushed to, is not decided — and it is the difference
between a stray that gets bulldozed down the road and one that stands.

**M4. Which pattern does a body take when its state does not say?**
The brain's states and the patterns are not one to one: walking covers march, lane_walk,
cross, withdraw and orbit depending on five other fields. Whether the pattern should be
chosen by the same run of tests that exists today, or become a field the brain writes so
that the choice is visible in the record rather than recomputed, is open.

## Related documents and tools

- [214 — going round what is in the way](214-going-round-what-is-in-the-way.md), whose
  circle test becomes the clearing rule of the lower layer
- [211c — a formation is a circle that faces](211c-a-formation-is-a-circle-that-faces.md)
- [211d — marching speed is not running speed](211d-marching-speed-is-not-running-speed.md),
  which this partly answers and partly reverses
- The formation sandbox, which is where all of this is measured
