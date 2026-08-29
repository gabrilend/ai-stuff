# 702 — The World Advances on a Move

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 605, 701 |
| Blocks | 705 |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Nothing advances, because nothing happens yet.

## Intended behavior

**The time is only ever now.** The world does not move by itself, and it does not
move when you drag the hour. It moves when you make a move, or press go on moves
you queued — see [605](605-the-queue-among-the-buttons.md).

### Dragging the hour is not time travel

It is **consulting your model of the city**. You are looking at what you
understand people to do, in order to plan. Shadows at three in the afternoon while
it is nine in the morning are not a prediction the game is making; they are what
*you believe* would be true then.

### The problem this dissolves

A clock that both ran and could be scrubbed would mean the screen could be showing
a moment that is not now — and then **every reading on it is a hypothetical**. The
shadows, everyone's whereabouts, the whole city.

That state has to be unmistakable or the map becomes untrustworthy in a way that
is very hard to notice, and marking it means a loud permanent indicator fighting
everything else on screen.

"The time is only ever now" removes the state entirely. Nothing needs marking,
because none of it was ever a live camera. The map is a document of belief and
always was.

This is the clearest instance of a pattern worth keeping: **a capability declined
is a category of problem that never has to be solved.**

### What advancing actually means

Whatever the mechanics eventually say. This issue builds **the discipline**, not
the consequences:

- exactly one path by which time moves forward, and everything that changes the
  world goes through it
- nothing anywhere else may advance anything
- dragging the hour touches that path not at all

Having one door is what will make the eventual mechanics testable, and what stops
a stray animation or an idle timer quietly aging the city.

## Suggested implementation steps

1. Define one function that advances the world; make it the only writer of
   anything that persists.
2. Make the hour a pure view parameter — reading it may change what is displayed
   and may never change what is stored.
3. Have go apply the queue through that single door, then clear it.
4. A direct move applies through the same door.
5. Test that dragging the hour across a whole day and back leaves every stored
   value identical, byte for byte. **That test is the guarantee** the rest of the
   design rests on.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
- [What this game is](../docs/001-what-this-game-is.md)
