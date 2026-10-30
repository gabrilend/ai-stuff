# 024-compile — the compiler and its validation wall

Raw score in, ready timeline out — or every mistake at once, each
naming its stroke and field, each miss teaching the nearest legal
word by edit distance (`047-nearest.lua`, shared with the 3D wall)
against the same vocabulary tables the runtime trusts. After the wall, every name becomes a number: clock words to
angles, hues to palette seats (in order of first use, in play
order), easing and fade names to functions, tip borrowings to
coordinates — forward borrowings legal (endpoints are geometry, not
history), circular borrowings refused.

## Usable surface

- **score(raw) → compiled** — raw is the reader's output (or any
  table shaped like it). Compiled carries: canvas facts (size, fps,
  length, seed), the declared hue list, the built palette, the
  timeline (tracks in play order, stable at ties — emission order
  is the random stream's order), and the pool capacity sized from
  the compiled demands.
- **PANE_WORDS**, **SAID_ELSEWHERE** — the words a pane takes, and
  the scene words a score says in its own calls rather than in
  `world{}`; the porch (issue 704) reads them to generate its grammar.

A score with a second space (issue 701d) — shapes, panes besides
the front one, or a background — is judged by the 3D wall
(`049-shape-wall.lua`) in the same pass, its lines said in the
score's terms (`shape #2 (tag).hue`, `camera`, `world`), and compiles
to `studio`: one timeline per pane (each its own random stream; the
front pane keeps the canvas's seed), the loaded world, the background
as light, the landmark cells a stroke follows a shape by, and the 3D
modules (loaded only for such a score). Its palette seats every house
hue (`compile.HOUSE_HUES`), as the shape films do. A score of strokes
alone on black compiles exactly as before.

Refusals cover: canvas sanity (size, fps dividing 100, tenths-
spoken length, whole seeds, gravity pairs), stroke time discipline
(tenths, inside the canvas), vocabulary words (hue, fade, ease,
emit fields, sweep, turn — all with nearest-word teaching), shape
structure, landmark discipline (absent names, tipless fills, self-
borrowing circles), and duplicate names; and for two spaces: length
or frames (not both), the background, pane words and places, strokes
on unknown panes, tips across panes, a tip of a shape on a world pane
or in a fill's corners, world words said elsewhere, and everything the
3D wall refuses.
