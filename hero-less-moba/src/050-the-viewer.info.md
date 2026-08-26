# 050-the-viewer

The window, the loop, and the two snapshots.

## What it is for

The world advances in fixed steps. The display advances whenever it feels like it. This
file reconciles the two clocks, and the reconciliation is one accumulator and one clamp.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load(root)` | project root | — Builds everything and opens the match. |
| `update(dt)` | | — |
| `draw()` | | — |
| `resize(w, h)` | | — |
| `keypressed` / `wheelmoved` / `mousepressed` / `mousereleased` / `mousemoved` | | — Forwarded to [input](049-input.info.md). |

`main.lua` at the project root is the doorway: LÖVE insists on that exact filename, so
it is the one unnumbered source file in the project. It works out the root, loads this,
and forwards the engine's callbacks. Nothing else belongs there.

## The loop

Real time piles up in an accumulator; whole ticks are taken out of it and handed to the
simulation; what is left over, as a fraction of a tick, is the blend between the two
most recent snapshots.

**Allowed to be behind. Never allowed to be ahead.** The blend is clamped at 1 rather
than trusted to stay there.

## Three clamps that keep the window responsive

**A long frame is truncated**, not simulated through. Catching up on four seconds of
ticks in one frame produces a longer frame, which produces more catching up, and the
window stops responding entirely.

**Ticks per frame are capped.** At high speed this is what stops the simulation
outrunning the display rather than dropping frames.

**Pausing drops the accumulator.** Keeping it would make unpausing spend the pause's
worth of real time on a burst of ticks.

## Interpolation is dropped above walking pace

At high speed a single displayed frame spans many ticks, and interpolating across them
shows positions between two states that were never adjacent. Above 1× the newest state
is drawn as it is — honest and slightly steppy, rather than smooth and invented.

## The camera gets the map's half of the window

Framing "the whole map" against the whole window would centre the map behind the panel,
so a player at rest would be looking at a map pushed a couple of hundred pixels off to
one side with a base partly hidden. The camera is handed a **rectangle**, not a size.

## The unattended capture

A renderer is the one part of this project that cannot be tested by asserting a number
— the question is always "does it look right" — and the next best thing is a picture
taken the same way every time.

| Variable | Meaning |
| --- | --- |
| `HLM_CAPTURE` | Where to write the png. Absent, none of this runs. |
| `HLM_CAPTURE_AT` | How many seconds of **match** to run first. |
| `HLM_CAPTURE_SPEED` | Ticks per real tick while getting there, so a picture of minute four does not take four minutes. |
| `HLM_CAPTURE_ZOOM` | `notches:x:y` — so the camera itself can be photographed doing its job. |

The picture is taken at the end of a `draw`, so it photographs a finished frame, and at
1× speed, so it is drawn the way a player would see it.

## The one banner

A finished match is the only thing in the game that takes over the screen, because it
is the only thing after which nothing else is worth looking at.
