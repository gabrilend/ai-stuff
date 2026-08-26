# 046-the-camera

A lens you push into.

## The one thing this file is for

**The point of the world under the mouse cursor does not move while you zoom.**

Everything else is subordinate to that. A camera that zooms about the centre of the
screen moves whatever you were looking at away from you, so the loop becomes zoom,
hunt, drag, zoom, hunt, drag. A player puts the cursor on the frontline they want to
read and turns the wheel; the frontline swells in place, and they never aim, because
they were already pointing at the thing.

Stated as a property, because it is a property
[the tests](../tests/051-the-invariants.info.md) assert with random anchors and random
scale changes:

```
screen_of(world_under_cursor) == cursor    -- before
screen_of(world_under_cursor) == cursor    -- after
```

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `create(bounds, vx, vy, vw, vh)` | map bounds, viewport rectangle | A camera. |
| `reframe(camera, vx, vy, vw, vh)` | | — New viewport; recomputes the rest framing. |
| `world_to_screen(camera, x, y)` | | Screen coordinates. |
| `screen_to_world(camera, x, y)` | | World coordinates. Exact inverse of the above. |
| `target_screen_to_world(camera, x, y)` | | The same, against the **target** rather than the drawn values. |
| `zoom_about(camera, factor, sx, sy)` | | — Scale by a factor, holding one screen point. |
| `wheel(camera, notches, cx, cy)` | | — Notches at the cursor. |
| `zoom_centre(camera, notches)` | | — Notches about the middle of the viewport. |
| `home(camera)` | | — Back to the whole map, instantly. |
| `begin_drag` / `drag_to` / `end_drag` | | — Drag-panning. |
| `pan_by_keys(camera, right, down, dt)` | | — Keyboard panning. |
| `update(camera, dt)` | | — Eases the drawn values toward the target ones. |
| `visible_rectangle(camera)` | | `left, top, right, bottom` in world coordinates. |
| `zoom_fraction(camera)` | | 0 at the whole map, 1 at the ceiling. |

## The camera record

Three pairs of values and an anchor.

| | Meaning |
| --- | --- |
| `target_x`, `target_y`, `target_scale` | What the player asked for. |
| `drawn_x`, `drawn_y`, `drawn_scale` | What is on screen this frame. |
| `rest_x`, `rest_y`, `rest_scale` | The whole map. Where it starts and where home returns it. |
| `origin_x`, `origin_y`, `width`, `height` | The **viewport rectangle** — the part of the window the map gets, which is not the whole window. |
| `anchor_*` | The point a zoom is being held around while the scale eases. |

## The behaviours

| | |
| --- | --- |
| **Rest state** | The whole map, framed with a margin, computed from the map's own bounds rather than written down. |
| **Home** | One key, instant, always available. Also the only thing that clears a drag in progress. |
| **Wheel** | Zooms about the **cursor**. Multiplicative per notch, so a notch is the same proportional change at every scale. |
| **Keyboard zoom** | Zooms about the **centre of the viewport**, because a player using the keyboard is not pointing at anything. Two anchors, chosen by which device asked. |
| **Smoothing** | The scale approaches its target exponentially, in log space. Frame-rate independent. |
| **Drag-pan** | The world point grabbed stays under the cursor. The same invariant, applied to translation. The centre snaps rather than easing — direct manipulation through treacle feels broken. |
| **Keyboard pan** | In **screen pixels per second**, not world paces, so panning feels identical at every zoom level. |
| **Zoom floor** | The whole-map framing. There is nothing further out, and a map adrift in empty space is a player who thinks they have lost the game. |
| **Zoom ceiling** | Close enough to read the upgrade badges off a single body. That requirement is what sets the number. |
| **Pan clamp** | The **centre** is held inside the map's bounds, not the edges — so a zoomed-in player can still put a corner of the map in the middle of their screen. |

## Zoom reveals detail. It never reveals events.

The rule constrains this file from two directions.

Forwards: anything a player must react to has to be legible at the rest framing, with
no zoom and no camera move.

Backwards, which is the half that lands here: **the camera never moves on its own.**
Not to follow a body, not to snap to a falling tower. If the game could move the camera
to show you something, then the camera's position would be carrying information, and a
player mid-drag when it fired has been robbed of it. The one exception that is not an
exception is home, which the player pressed.

## The trap the design defends against

The drawn scale lags the target scale. If the zoom arithmetic were done against the
drawn value, every notch during a fast scroll would anchor to a slightly stale point
and the world under the cursor would **creep**.

So the arithmetic is done against the **target** — that is what
`target_screen_to_world` is for — and the anchor is then re-honoured every frame
against the drawn scale as well. That second half is what keeps the point under the
cursor fixed *during* the animation and not merely at the end of it.

## Why the smoothing is not decoration

A snapped zoom at a high notch rate reads as teleporting and a player loses track of
where they were, which reintroduces the hunt this file exists to delete. The easing
keeps the two views connected: you can see the frame you left travelling toward the
frame you asked for, so you arrive already knowing where you are.

The scale eases in **log space**, so 1× to 2× takes as long as 4× to 8×. Zoom is
perceived proportionally, and easing it linearly makes the far end of the range crawl.
