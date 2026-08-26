# What a viewer is allowed to know

One rule, and everything in this document is a consequence of it:

> **The server never sends a viewer something they are not entitled to know.**

Not sends-and-marks-it-hidden. Not sends-and-trusts-the-client-to-omit-it. Never
puts it on the socket.

## Why the other way is not a smaller version of this

The convenient design is to send everyone the whole world and let each client draw
only the part its owner should see. It is one outbound message instead of twelve,
it makes the client simpler, and every part of it works perfectly until somebody
opens the browser's developer tools.

At that point they have the position of every ambush, the layout of every
unexplored corridor, and whatever the GM wrote in their notes. Not through
cleverness -- by pressing F12 and reading a variable. The information was on their
machine the entire time, and no amount of care in the drawing code changes that.

The fog would be a *drawing effect*: a dark rectangle painted over information the
viewer already has. That is a curtain, and this project needs a wall. So the fog
computed in [sight and what it remembers](007-sight-and-what-it-remembers.md) is
not there to make the picture pretty. It is there because the outbound pass needs
to know which records it may write.

The whole cost of this decision is that the expensive geometry has to run on the
host's machine, once per viewer, every tick. That is what pass 5 of
[the tick](004-the-world-and-its-tick.md) is, and it is why it goes to the thread
pool.

## The filter

Pass 7 builds one message per viewer. Each candidate record passes four gates in
order, cheapest first:

| Gate | Question | Source |
| --- | --- | --- |
| 1. Scope | Is this thing inside a scope this viewer holds? If so it passes everything below -- you always know about what you command. | [008](008-who-controls-what.md) |
| 2. Hidden | Is `HIDDEN` set, and does no scope of this viewer have `MAY_SEE_HIDDEN`? Then it never passes, no matter what the geometry says. | [005](005-a-thing-in-the-world.md) |
| 3. Sight | Is it inside the viewer's visibility polygon this tick? Bodies need this. | [007](007-sight-and-what-it-remembers.md) |
| 4. Memory | Is its cell set in the viewer's fog bitmap? Walls need only this -- terrain is remembered, bodies are not. | [007](007-sight-and-what-it-remembers.md) |

A scope with `SEES_ALL` passes gates 3 and 4 trivially, which is what makes a GM's
outbound message cheap to build and large to send.

### The fields inside a record are filtered too

Passing the gate is not the same as being sent whole. A goblin that a player can
see is sent as a position, a facing, a radius, and a `kind`. Its `sheet` index --
the door into the ruleset's numbers for it -- is not sent, because a player who can
see a goblin is not thereby entitled to its hit points.

The ruleset decides what part of a sheet a given viewer may know, because that is
a statement about the game rather than about geometry. Some systems show
everybody's numbers; some show none. The server asks and does not guess. See
[the rules layer](011-the-rules-layer.md).

Free-text attached to things -- a GM's notes -- is never sent to a viewer without
`MAY_SEE_HIDDEN`, and this is a hard rule in the server rather than a question put
to the ruleset, because a ruleset should not be able to leak the GM's notes by
being written carelessly.

## The filter is the only path out

There is exactly one function that writes a thing record to a socket, and it takes
the viewer as an argument. Nothing else in the server may write a thing record to
a socket. This is the discipline that makes the rule above auditable: the question
"can this leak?" is answered by reading one function and checking who calls it,
not by reading the whole program.

The same function serves replays. A replay of a session from one participant's
seat is that participant's stream, which means a replay cannot show more than the
session did, which means a replay is safe to hand to somebody who was at the
table.

## How this gets tested

The leak test is the most important test in the project and it is cheap, so there
should be many of them:

1. Build a world with a thing the viewer must not know about -- behind a wall,
   flagged hidden, outside their scope.
2. Run a tick.
3. Take the viewer's outbound bytes and search them for the thing's index and its
   coordinates.
4. Fail if found.

That runs in the build. It does not test the drawing, it does not test the sight
polygon's exact shape, and it does not care how the filter is implemented. It
tests the one sentence at the top of this document, which is the one that matters.

Every time the filter grows a new gate or a new field, it grows a leak test with
it. Not because there is an issue file asking for one -- because the thing has to
actually work.

## Read next

- [Commands enter through one door](010-commands-enter-through-one-door.md) --
  the other direction, where the trust question inverts.
- [The rules layer](011-the-rules-layer.md) -- the one part of the system that is
  asked what a viewer may know.
