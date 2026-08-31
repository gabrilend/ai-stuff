# 104 — Pan and Zoom by Hand

| | |
| --- | --- |
| Phase | 1 — The Canvas |
| Blocked by | 102 |
| Blocks | 302, 408, 604 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — *(was question 1; answered)* |

## Current behavior

The view can be moved by setting its three numbers. Nothing moves it in response
to a hand.

## Intended behavior

**Two buttons, two meanings, and they are the opposite way round from what
anybody expects.**

| Input | What it does |
| --- | --- |
| **middle drag** | pans the map |
| **wheel** | zooms, anchored on the pointer |
| **left click** | selects a place, and explains a control |
| **right click** | modifies — presses a control |

Looking and doing are separate hands. Left is enquiry; right is action.

### The inversion is a stance, not an oversight

Pressing a button with the right hand and being told what it does with the left
is contrary to every convention, and that is the point: **the interface asks to
be learned rather than guessed**, and refuses the muscle memory a person arrives
with.

Anybody later tempted to make this friendlier should understand they are undoing
a decision rather than fixing a mistake.

What it costs, once, plainly: a middle-button drag is awkward on a trackpad, and
panning is the thing you do most.

### It dissolved the conflict this issue was raised about

The worry was that the tracing tool needs the same gestures for a different job —
a drag there might mean moving a vertex, and the two programs must not disagree
about what a drag means.

They do not, because **panning is the middle button and editing is the left and
right buttons**. A drag on empty ground is never editing in either program. The
overlap that made this a question does not exist.

### Zoom is anchored to the pointer

The painting pixel under the cursor **stays under the cursor** as the zoom
changes. Anything else feels like the city sliding away from what you are looking
at.

Mechanically: note the painting point under the pointer, apply the new zoom, then
set the pan so that point maps back to the same screen position. Two calls to the
conversions in [102](102-the-view-is-an-offset-and-a-scale.md) and a subtraction —
and the difference between a view that feels attached to your hand and one that
does not.

### Zoom steps multiply

Each notch multiplies rather than adds. Adding a constant makes the zoom crawl
when far out and leap when close in; multiplying gives the same felt step
everywhere.

Clamped below at the pane fit. **Not clamped above** — past native is allowed and
looks like blur. See [102](102-the-view-is-an-offset-and-a-scale.md).

### What space is not

**Space is taken** by the search — see [609](609-space-to-search.md). It is not a
pan modifier here, however common that is elsewhere. Nothing on the keyboard
pans; panning is a mouse button.

## Suggested implementation steps

1. Middle drag on the map pane pans, by the screen delta divided by zoom.
2. Wheel multiplies the zoom by a constant per notch, anchored at the pointer.
3. Clamp the pan always; clamp the zoom below only.
4. Left click selects, at the level the zoom has chosen —
   [408](408-the-zoom-picks-the-level.md).
5. Keep the binding table separate from the behaviour, so the tracing tool reuses
   the behaviour and supplies its own table for the left and right buttons.
6. Confirm by eye that a building under the cursor stays under the cursor across
   the whole zoom range, including well past native, at several points including
   the far corners of the painting.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md) — the hands, and what they cost
- [The tome](../docs/007-the-tome.md) — where left-asks-right-acts lands on controls
