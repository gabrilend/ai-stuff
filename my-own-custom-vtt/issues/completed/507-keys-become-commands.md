# 507 -- Keys become commands

**Phase:** 5, the bridge and the browser
**Blocked by:** [503](503-the-view-receives-state.md)
**Blocks:** [508](508-the-phase-five-demo.md)
**Documents:** [commands enter through one door](../docs/010-commands-enter-through-one-door.md)

## Current behaviour

The view draws. Nothing goes back the other way.

## Intended behaviour

Held keys become a direction being pushed. Clicks become destinations.

### A held key is a state, not an event

`VERB_DRIVE` says "I am pushing this way", not "step once". So the view sends a
drive command when the set of held keys **changes**, and a stop when the last one
lifts -- not one per frame.

That matters for three reasons. It is what makes the server's standing-order model
work rather than being fought. It means a browser dropping a frame does not drop a
step. And it means the command rate is bounded by how fast somebody can move their
fingers rather than by their monitor.

**Diagonals are one command.** Two keys held is one direction, computed from both,
not two commands that fight.

### Clicks are destinations

`VERB_ORDER_MOVE` with a world position, converted from a screen position by the
inverse of whatever transform drew the frame.

That conversion is the one place the view does arithmetic the server will act on,
so it goes through a single function rather than being written inline at each call
site -- a screen-to-world conversion written twice is written differently twice.

**Commands carry metres.** The view displays feet, rounded, and never converts
back: two clients rounding differently would disagree about where somebody
clicked. See [a thing in the world](../docs/005-a-thing-in-the-world.md).

### Refusals are shown

Not in a console. Where the person who pressed the key is looking, as the sentence
the server sent. A refusal nobody sees is a silent drop with extra steps.

## Suggested implementation steps

1. Track held keys. Send on change, not per frame.
2. Compute one direction from all held keys.
3. Convert screen to world in one function, and use it everywhere.
4. Show refusals in the view, briefly, in words.
5. Write the companion `.info.md`.
6. Test the screen-to-world conversion against its inverse: a world point drawn
   and then converted back must land where it started.
