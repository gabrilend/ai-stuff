# Two Bodies Meeting

Everything that happens between two bodies happens here, in one pass, in one
place. There is no other pass in which one body reads another's state and
changes it.

## Why it is one pass

Because pairing is the one thing in the simulation that is not independent per
body, and confining it to a single pass is what lets every other pass be split
across cores without anybody thinking about it. See
[the tick](010-the-tick.md).

If a body could pair with another during the `decide` pass, then two bodies
running on two cores could each decide to pair with the same third body, and
which one won would depend on thread timing. Every other pass is safe precisely
because this one is not, and this one is small precisely because it is the one
that cannot be.

## How a pair is found

The `index` pass left a bucket per cell. For each body, in order, the meet pass
looks at its own bucket and the eight around it, and considers each body it
finds there whose id is **greater than its own**.

That last condition is what stops every pair being considered twice, and it costs
one comparison instead of a set of already-seen pairs. It also means the pass is
a single sweep with a bounded amount of work per body no matter how many bodies
there are, which is the property that makes the population a knob rather than a
cliff.

## What happens when two bodies are adjacent

A dispatch table again, indexed by the two creature kinds. The table says what
this pairing means, and the entry is a function.

| One | The other | What happens |
| --- | --- | --- |
| little guy | little guy | if both idle and both willing, a [shared idle](015-idling-and-being-idle-together.md); otherwise they step around each other |
| fencer | fencer, other team | a duel begins. See [fencing](017-fencing.md). |
| fencer | fencer, same team | they pass |
| anything | anything, same cell | the collision case below |
| human | dinosaur, willing | [mounting](022-riding-and-being-ridden.md) |
| delver | monster | a fight, by the monster's rules |

Indexed by two kinds rather than tested with a chain of conditions because the
chain grows as the square of the number of creatures, and because a table can be
printed. Being able to print the complete list of what any two things do when
they meet is worth more than it sounds — it is the fastest way to notice that
nobody wrote down what happens when a golem meets a ball.

## Stepping around each other

Two walkers that want the same surface: the one with the lower id gets it, the
other re-decides next tick. Deterministic, cheap, and slightly unfair in a way
nobody can perceive.

Two walkers that are already in the same cell — which happens when one spawns on
top of another, or when the stone changes under them — are pushed apart along the
line between them, one cell each, into whichever adjacent surface is enterable. If
neither can move, they stay overlapped, and the headless report counts it. An
overlap that persists is a real problem; an overlap that resolves next tick is
not; and the only way to tell them apart is to count.

## Related documents and tools

- [The tick](010-the-tick.md) — why this pass is where it is
- [A body and what it carries](011-a-body-and-what-it-carries.md) — `partner` and its generation
