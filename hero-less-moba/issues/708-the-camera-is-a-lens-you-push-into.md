# 708 — The Camera Is a Lens You Push Into

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 701 |
| Blocks | 702, 703, 705 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) |
| Open questions | none |

## Current behavior

Issue 701 asks for "a zoom scalar and a centre" and one binding that returns to
the whole-map framing. That is the whole specification the camera has, and it is
not enough to build one that feels like anything.

It leaves out the question a player actually notices, which is not *whether* the
view can zoom but **what the zoom is anchored to.** A camera that zooms about the
centre of the screen moves whatever you were looking at away from you, so the
loop becomes zoom, hunt, drag, zoom, hunt, drag. That is the small navigation
task D7 says must not exist. D7's ruling — that returning home must be one
instant action — was aimed at the trip back; the same failure exists on the trip
out, and nothing in the documents addresses it.

## Intended behavior

**The point of the world under the mouse cursor does not move while you zoom.**

That is the entire feature and everything else in this issue is subordinate to
it. A player puts the cursor on the frontline they want to read and turns the
wheel; the frontline swells in place. They never aim, because they were already
pointing at the thing.

### The invariant, stated so it can be tested

The camera is a mapping from a world point to a screen point. Let `screen_of()`
be that mapping. Zoom-to-cursor is the requirement that, for the cursor position
`c` and any change of scale:

    screen_of(world_under_cursor_before) == c    -- before the zoom
    screen_of(world_under_cursor_after)  == c    -- after the zoom

Which is satisfied by inverting the mapping at the cursor *before* changing the
scale, and then solving for the centre that puts that same world point back under
the cursor afterwards. Two lines of arithmetic. It is written here as an equality
rather than as a procedure because it is **a property a test can assert** — pick
a random cursor position and a random scale change, and the world point under the
cursor must be unchanged to within floating-point tolerance. That test is worth
more than the two lines it checks, because every later camera feature is a chance
to break it silently.

### The rest of the lens

| | Behaviour |
| --- | --- |
| **Rest state** | The whole map, framed with a margin, recomputed from the map's own bounds rather than written down. This is where the camera starts and where home returns it. |
| **Home** | One key, instant, always available. Also the only thing that clears a drag in progress. |
| **Wheel** | Zooms about the cursor. Multiplicative per notch, so a notch is the same *proportional* change at every scale — additive steps crawl when zoomed in and jump when zoomed out. |
| **Keyboard zoom** | Zooms about the **centre of the screen**, not the cursor, because a player using the keyboard is not pointing at anything. Two anchors, chosen by which device asked. |
| **Smoothing** | The scale approaches its target exponentially rather than snapping. The target is what the wheel writes to; the current value is what draws. Frame-rate independent, so the easing is the same on a 60Hz and a 144Hz display. |
| **Drag-pan** | Held middle or right mouse drags the world. The world point grabbed stays under the cursor for the length of the drag — the same invariant as the zoom, applied to translation. |
| **Keyboard pan** | Arrows and WASD, at a speed measured **in screen pixels per second, not world paces**, so panning feels identical at every zoom level. |
| **Zoom floor** | The whole-map framing. You cannot pull back further, because there is nothing out there and a map adrift in empty space is a player who thinks they have lost the game. |
| **Zoom ceiling** | Close enough to read the upgrade badges off a single body, which is issue 702's close-zoom requirement and therefore the thing that sets this number. |
| **Pan clamp** | The centre is held inside the map's bounds, so the map can never leave the frame entirely. Clamped at the centre rather than at the edges, so that a zoomed-in player can still put a corner of the map in the middle of their screen. |

### What this does not get to do

**The camera never moves on its own.** Not to follow a hero, not to snap to a
falling tower, not to frame a challenge monster. That is D7's rule — *zoom
reveals detail, it never reveals events* — read from the other side: if the game
is allowed to move the camera to show you something, then the camera's position
is carrying information, and a player who was mid-drag when it fired has been
robbed of it. Every event stays legible in the rest framing, so there is never a
reason to move.

The one exception that is not an exception: **home**, which the player pressed.

### Why the smoothing is not decoration

A snapped zoom at a high wheel-notch rate reads as teleporting, and a player
loses track of where they were — which reintroduces the hunt this issue exists to
delete. The easing is what keeps the two views connected: you can see the frame
you left travelling toward the frame you asked for, so you arrive already knowing
where you are.

The cost is that the drawn scale lags the target scale, and the zoom-to-cursor
arithmetic has to be done against the **target**, not the drawn value, or every
notch during a fast scroll anchors to a slightly stale point and the world under
the cursor creeps. That is the bug this paragraph exists to prevent.

## Suggested implementation steps

1. Write the camera record: a target centre, a drawn centre, a target scale, a
   drawn scale, and the rest framing computed from the map bounds.
2. Write `world_to_screen` and `screen_to_world` as a matched pair, and never
   compute either one inline anywhere else. Every camera bug in every project is
   two copies of this arithmetic that disagree.
3. Write the zoom about an arbitrary screen anchor. Wheel passes the cursor;
   keyboard passes the screen centre. One function, two callers.
4. Write the exponential approach, taking the frame's delta time, and check it on
   two different refresh rates.
5. Write the clamps — scale floor and ceiling, centre inside bounds — as one
   function applied after every mutation, rather than at each call site.
6. Write the property test from the invariant above: random anchor, random scale
   change, world point under the anchor unchanged.
7. Write the drag-pan, and make **home** cancel a drag in progress rather than
   leaving the camera captured by a button the player has forgotten.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md) — D7, and the rule that
  zoom reveals detail and never events
- Issue 701, which owns the window this camera draws into
- Issue 702, whose close-zoom requirement sets the zoom ceiling

## Still open

Nothing blocking.

Whether a **zoom-to-region drag** — hold a modifier, drag a rectangle, fly the
camera to it — is worth having on top of the wheel. It is the one camera gesture
that is faster than the wheel for "show me that whole fight," and it is also the
one most likely to be discovered by accident and mistaken for a selection box.
Not built.
