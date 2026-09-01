# 069-the-proving-ground

The window onto [the arena](068-the-arena.info.md): ground, bodies, a caption, and
nothing that belongs to a match.

## What it is for

The ordinary viewer draws a game — chest panel, hero roster, sign-posts, push-depth
bands, upgrade badges, a wallet, a clock. Every one is there because a player needs it,
and every one is a thing that has to be visually discounted before the rule you came to
look at can be seen. **What is absent here is the feature.**

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load(root, scene)` | | — Reads the scene, builds its arena, places its bodies, holds. |
| `update(dt)` | | — Advances the scene's own mechanics at the scene's own rate. |
| `draw()` | | — Ground, bodies, readout. |
| `keypressed(key)` | | — P holds, 1/2/3 speed, R restarts, ESC closes. |

Reached through `main.lua` when `HLM_START` reads `arena:<scene>`, which is the one
decision left in that doorway: there are two windows in this project and they are not
two versions of one thing.

## What is on the screen

**The mechanics the scene declared**, above the ground. The honesty of the whole
arrangement rests on being able to see which machinery made a picture. A scene may add
a `note` under it, and should whenever a module is present for a reason other than the
obvious one.

**The ground**, drawn from the lane's own path and width rather than from the arena's
numbers — so if those ever disagree, the picture shows the lane the bodies are actually
walking. Milestone marks are the only distance scale.

**The bodies.** Discs for melee, wedges for anything with a reach, the same vocabulary
the match renderer uses. A stray — a body in no formation — is drawn in its own colour
with a ring showing the room it keeps, because a stray is a thing in the way rather
than one more soldier.

**A red ring on every body the queue is stopping this tick.** The match viewer does not
show this and this one must: who is blocked is the entire question the first scenes ask.

Bodies are drawn **larger** than the match renderer draws them, which reverses that
file's rule. A match is a map and its bodies are weather; an arena is a diagram of a
dozen soldiers and the reader has to tell them apart individually. The personal-space
ring is drawn at its true size, so the honest number is on the screen beside the
generous one.

## The camera is one rectangle

Framed once on the road, never panned or zoomed. A pan-and-zoom camera is right for a
map you are exploring and pure overhead for a rectangle that fits on the screen. The
readout sits directly under the ground wherever the ground ends, rather than at the
bottom of the window — on a tall display those were a screen apart, and a caption you
have to look away from the picture to read is a caption about a different picture.

## Photographing a scene

`HLM_CAPTURE` with `HLM_CAPTURE_AT` runs to an exact tick, writes a PNG and quits, so
a scene can go into a document without anybody being at the keyboard at the right
moment. The tick is exact rather than a wall-clock delay, so the same request twice
gives the same picture.
