# 404 -- One function writes to a socket

**Phase:** 4, people connect
**Blocked by:** [402](402-a-session-is-a-socket.md),
[403](403-the-wire-format.md)
**Blocks:** [407](407-the-leak-test.md)
**Documents:** [what a viewer is allowed to know](../docs/009-what-a-viewer-is-allowed-to-know.md)

## Current behaviour

Nothing is sent anywhere.

## Intended behaviour

**The most important file in the project.** One rule, and everything here is a
consequence of it:

> The server never sends a viewer something they are not entitled to know. Not
> sends-and-marks-it-hidden. Not sends-and-trusts-the-client. Never puts it on
> the socket.

### There is exactly one function that may write a thing record to a socket

It takes the viewer as an argument. **Nothing else in the server may write a thing
record to a socket.**

That discipline is what makes the rule auditable: the question "can this leak?" is
answered by reading one function and checking who calls it, rather than by reading
the whole program. A rule enforced in one place is a rule; a rule enforced in
forty places is a habit.

### The four gates

Cheapest first.

| Gate | Question |
| --- | --- |
| 1. Scope | Is this inside a scope this viewer holds? If so it passes everything below -- you always know what you command. |
| 2. Hidden | Is `THING_HIDDEN` set, and does no scope of theirs have `MAY_SEE_HIDDEN`? Then it never passes, whatever the geometry says. |
| 3. Sight | Is it inside their visibility right now? **Bodies need this.** |
| 4. Memory | Is its cell in their fog? **Walls need only this** -- terrain is remembered, bodies are not. |

Scopes do not exist until phase 6, so gate 1 passes everything and gate 2 reads a
flag nothing sets yet. The gates are **written now, in order, with the later ones
stubbed** -- because inserting a gate into a filter that already works is how a
gate gets inserted in the wrong place.

### Fields inside a record are filtered too

Passing a gate is not being sent whole. A goblin a player can see is sent as a
position, a facing, a radius, and a `kind`. Its `sheet` -- the door into the
ruleset's numbers -- is not, because seeing a goblin does not entitle you to its
hit points.

### Why not send everything and hide it client-side

It is one message instead of twelve and works perfectly until somebody presses
F12. Then they have every ambush, every unexplored corridor, and the GM's notes --
not through cleverness, by reading a variable.

The fog would be a *curtain*. This project needs a wall.

## Suggested implementation steps

1. Write the one function. Give it a name that makes calling anything else feel
   wrong.
2. Write the four gates in order, with 1 and 2 present and permissive.
3. Filter fields, not just records. `sheet` never goes out in this phase.
4. Send walls from memory and bodies from sight, and comment why they differ.
5. Write the companion `.info.md` -- and list, in it, every caller. That list is
   the audit.
6. Test with [407](407-the-leak-test.md), which is the real test of this file.
