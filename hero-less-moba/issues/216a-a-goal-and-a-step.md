# 216a — A Goal, and a Step

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 216 |
| Blocks | 216b |
| Reads | [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | M2, M3 |

## Current behavior

There is no such thing as *where a body wants to be*. There is only what it did this tick.

Every mover computes a displacement and applies it in the same breath, so the intention
never exists as a value anybody can read, draw, assert on, or hand to another rule. The
closest thing is a formation's place for a body, which is recomputed on demand inside the
one function that walks toward it.

The consequence shows up wherever something else needs to know what a body was trying to
do. The rule that keeps bodies out of each other has to be handed a point by the caller,
because there is nowhere to read one from. The window cannot draw where anybody is going.
A test cannot say "this body should be heading up the lane" — only "this body ended up
further up the lane", which is also true of a body that was pushed.

## Intended behavior

**Two points on every body, and one thing that moves it.**

| Field | Type | Meaning |
| --- | --- | --- |
| `goal_x`, `goal_y` | double | where this body wants to be, in world paces. May be a long way off. |
| `goal_pace` | integer | 1 relax, 2 normal, 3 hurry |
| `step_x`, `step_y` | double | where it will stand at the end of this tick |
| `moved` | integer | 1 if the step was moved out of somebody — what the window rings in red |

Both are **world** points, and that is the change that buys the modularity. A body on a
lane and a guard at a tower have kept their positions in two different currencies since
the beginning, and every rule that wanted to nudge either one has had to know which. One
currency for intentions, and one place that converts.

### The three things the lower layer does, in order

**Cap.** The step starts at the goal and is pulled back along the line to the body until
it is no further away than `pace × speed`, measured in the world. A goal ninety paces off
therefore produces a step one pace off, every tick, and the body converges on it.

**Clear.** The capped step is asked the question that already exists: is anything standing
within `self.radius + other.radius` of it? If so it moves to the nearest point that is not
— out along the line from the obstacle's centre through the step, which is the existing
rule and the existing reasoning for it.

**Place.** The body is put on the cleared step, through whichever representation its
position lives in: lane coordinates for anything on a road, a node and an offset for a
guard. **One conversion, in one place**, rather than every mover knowing which kind of
body it is holding.

### What this deletes

The three-pass scaling that measures how far a body actually moved and rolls it back if it
went too far exists because lane coordinates make a turn free and a body on the outside of
a bend was silently covering more ground than its speed allowed. Capping the step at a
world distance *before* converting means the outer body never gets the extra ground in the
first place. The correction becomes unnecessary rather than better.

### What it does not change

A marching body's goal is still computed **in lane coordinates and converted at the end**.
That is what makes a rank curve round a bend as a rank, and it is a property of how the
goal is computed rather than of how it is stored. Nothing in the layer below cares.

## Suggested implementation steps

1. Put the four fields on the body record, zeroed at birth like every other field, so
   nothing ever reads a nil.
2. Write the capping, the clearing and the placing as three small functions in the walking
   module, and one that runs them in order.
3. Give the placing step the two representations it has to write through — this already
   exists as the nudge the separation pass uses, and wants to be the same function.
4. Move the marching body onto it first and check the formation sandbox still recognises a
   formation. That suite is the only reason to believe any of this.
5. Draw the goal and the step in [the proving ground](111-the-proving-ground.md): a line
   from each body to where it is trying to be. Half of what this issue is for is that the
   intention becomes something a person can look at.
6. Add a reading to [the measurement catalogue](../src/070-what-can-be-measured.info.md)
   for how far bodies are from their goals, so a formation coming apart is a number as
   well as a picture.

## Related documents and tools

- [216](216-movement-is-a-goal-and-a-step.md), the umbrella
- [214 — going round what is in the way](214-going-round-what-is-in-the-way.md)
