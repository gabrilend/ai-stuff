# 407 -- The leak test

**Phase:** 4, people connect
**Blocked by:** [404](404-one-function-writes-to-a-socket.md)
**Blocks:** [408](408-the-phase-four-demo.md)
**Documents:** [what a viewer is allowed to know](../docs/009-what-a-viewer-is-allowed-to-know.md)

## Current behaviour

Nothing is sent, so nothing can leak.

## Intended behaviour

**The most important test in the project, and it is cheap, so there should be
many of them.**

1. Build a world with a thing the viewer must not know about -- behind a wall,
   flagged hidden, or outside their scope.
2. Run a tick.
3. Take the viewer's outbound bytes and search them for the thing's index and its
   coordinates.
4. Fail if found.

### What makes it the right test

It does not test the drawing. It does not test the visibility polygon's exact
shape. It does not care how the filter is implemented.

It tests **the one sentence** the outbound filter exists to make true, by looking
at the only thing that actually matters: the bytes that left the machine.

That is why it searches raw bytes rather than asking the filter whether it would
have sent something. Asking the filter is asking the accused. A test that shares
an implementation with the thing it is testing agrees with it about the bug too.

### The cases

| Case | What it catches |
| --- | --- |
| A body behind a wall | The sight gate. |
| A body in an unexplored room | The memory gate, for walls. |
| A body flagged `THING_HIDDEN` standing in plain view | The hidden gate overriding geometry. |
| A body outside the viewer's scope | The scope gate -- stubbed now, real in phase 6. |
| A `sheet` index on a visible body | Field filtering. Seeing a goblin does not entitle you to its numbers. |
| The GM's notes | Never sent to anyone without `MAY_SEE_HIDDEN`, as a hard rule in the server rather than a question put to a ruleset. |

### It grows with the filter

Every time the filter grows a gate or a field, it grows a leak test with it. Not
because an issue file asked -- **because the thing has to actually work**, and
this is the only durable statement of what working means.

### A false negative is worse than a failure

A leak test that passes because it searched for the wrong bytes is worse than no
test, because it retires the suspicion. So each case must also be run **inverted**
-- move the body somewhere visible and assert the search now DOES find it. A test
that cannot detect the thing it is looking for is not testing anything.

## Suggested implementation steps

1. Write the byte search: given a viewer's outbound buffer, look for a thing's
   index and its packed coordinates.
2. Write each case above, in a table so adding one is adding a row.
3. Write the inverted half of every case in the same row.
4. Wire it into the build, not into a script somebody remembers to run.
5. Write the companion `.info.md`.

## Related

The same function that filters for a socket serves replays, so a replay cannot
show more than the session did -- which means a replay is safe to hand to
somebody who was at the table. Worth a case here too.
