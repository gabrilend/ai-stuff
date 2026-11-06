# 078-where-it-was-refused

Where a refusal is shown: beside the place the refused thing was attempted, rather than in a corner.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Issue 704, step 4. A refusal is the game's only manual, and it teaches best where the
player's eyes already are: beside the stone they just dropped, the slot they just
clicked, the place they just pinged. This file is the viewer's bookkeeping for that. It
remembers where each of this player's commands was made, and when one comes back
refused, it puts the sentence there.

It is pure and LÖVE-free, so it is tested headless. The
[panel](048-the-panel.info.md) draws what `current` returns. The simulation never reads
it: the one thing the simulation gives it is the arrival number that every refusal now
carries back.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `settings` | | The numbers, each chosen by Claude and open for Ritz. |
| `create()` | | An empty book. |
| `attempted(book, command, place)` | a queued command, `{space, x, y}` | — Remembers where it was made. Errors on a command with no arrival number. |
| `show(book, text, place, now)` | | — A sentence at a place, now. For refusals the input layer makes itself. |
| `settle(book, events, player, now)` | a tick's events | The refusals that had no place, for the corner list. Empties the attempts. |
| `current(book, now)` | | What is showing, newest first, each with `age` (0 to 1) and `newer_nearby`, the indices of the newer ones close enough that it stacks above them. |

## Data structures it owns

| Field | Holds |
| --- | --- |
| `book.attempt` | This player's commands since the last tick: player, arrival, verb and place. |
| `book.shown` | Sentences showing, newest first, each with its place and when it was made. |

A place is `space = "world"` in world units, for anything done on the map, so that the
sentence stays on the ground it is about while the camera moves; or `space = "screen"`
in pixels, for anything done on the panel, which does not move.

## The numbers

| Setting | Value | Why |
| --- | --- | --- |
| `lifetime` | 6 seconds | The same as the corner list always used. |
| `most` | 4 | Older go first; a fifth line is wallpaper. |
| `lift` | 22 px | The newest line sits above the point, not under the cursor. |
| `line` | 15 px | The height of one line of a sentence. |
| `width` | 280 px | Before a sentence wraps onto a second line. |
| `crowd_world`, `crowd_screen` | 40 units, 60 px | Two places this close stack rather than overlap. |

All chosen by Claude, open for Ritz, and none looked at on screen.
