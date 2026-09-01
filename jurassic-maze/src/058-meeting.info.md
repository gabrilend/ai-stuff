# 058-meeting

The one pass where two bodies affect each other, and the table of what that
means.

Read this page rather than the source, and read
[two bodies meeting](../docs/016-two-bodies-meeting.md) before either.

## What it is for

Everything that happens between two bodies happens here. No other pass reads one
body's state and changes another's.

That is not tidiness. Pairing is the only thing in the simulation that is not
independent per body, and confining it to one pass is what lets every other pass
be split across cores without anybody thinking about it. This pass is small
precisely because it is the one that cannot be.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(Stone, BodyStore, Walking, Creatures)` | | hands in the modules at world creation |
| `new_table(creatures)` | | the meet table, indexed by the two creature kinds |
| `pass(world, dt)` | | one tick of pairing |
| `describe(world)` | | the whole meet table, printed |

`describe` is read by nothing. It is here so that a person can read the complete
list of what any two things do when they meet, which is the fastest way to notice
that nobody wrote down what happens when a golem meets a ball.

## The greater-id rule

For each body, its own bucket and the eight around it, considering only bodies
whose **id is greater than its own**. One comparison, instead of a set of
already-seen pairs, and it keeps the pass a single sweep with bounded work per
body no matter how many bodies there are.

## Three things this file learned the hard way

**A mirrored rule shares its function.** `pair(a, b, …)` writes the entry both
ways, with the mirror swapping its arguments, so a rule is written once and
cannot be written twice differently.

**The bucket ranges are walked directly, not through a callback.** The callback
version reads better and allocates a closure per body per tick — at seven hundred
bodies, a quarter of a million closures a minute, for a loop of four lines. The
collector then arrives in the middle of a frame for reasons nothing on screen
explains. Removing it made this pass four and a half times faster.

**Separation displaces whichever body is not on an errand.** Always displacing
the higher id is simpler and quietly destroys errands: a body pushed a cell
sideways is no longer at the start of the path it was following. At any real
density that happened to nineteen errands in twenty, and the feature looked as
though it did not work rather than as though it was being interrupted.

## The shared idle

Two little guys, both standing about, both having stood about for
`notice_seconds`, both unpartnered: the same idle row, the same clock, and each
facing the other.

That is the whole mechanism, and it is enough to produce something that reads as
two people having a conversation. **Nobody is having a conversation.** There are
two timers set to the same value and two facings pointed at each other, and there
is no dialogue, no relationship, and no memory of it afterwards.

The wait matters. Without it, two bodies that happen to pause on the same tick
lock together instantly and the maze fills with pairs — which reads as magnetism
rather than as company.

## Overlaps are counted, not assumed away

Two bodies in one cell are pushed apart. If neither can move they stay
overlapped, and it is counted: an overlap that persists is a real problem, one
that resolves next tick is not, and counting is the only way to tell them apart.
