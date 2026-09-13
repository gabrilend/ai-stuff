# 603 — A view is a lens you adjust

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 601 |
| Blocks | 605, 606, 607, 802 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. The test program `tests/024-watching-it-happen.lua` looks for a source
file with the stem `lenses` and the exports named in
[the tests come first](../docs/014-the-tests-come-first.md) — `push`,
`to_screen`, `to_field` — and fails today because no such file exists. The
property it asserts, that a push keeps the point under the cursor fixed, is
already written down.

## Intended behavior

There is not one view of the field. There are as many as the player arranges,
each one a **lens**: a small record, and a viewer holds a list of them and draws
every one from the same snapshot.

| Field | Type | Holds |
| --- | --- | --- |
| layer | integer | which layer table row this lens draws |
| anchor_x, anchor_y | double | the field point at the centre of the lens |
| zoom | double | screen pixels per field cell |
| x, y, width, height | integer | the rectangle on the screen the lens occupies |

The layers are a dispatch table indexed by the lens's layer field: the dunes,
territory, units, patterns, sightlines, the cloud. Each row is a draw function
taking a lens and the snapshot pair. Adding a layer is adding a row, and a lens
whose layer is not a row is a load-time error, not a blank rectangle.

**Two transforms and a push.** `to_screen` takes a field point to a screen point
through the lens's anchor and zoom; `to_field` is its inverse. `push` zooms the
lens by a factor about a screen point and **moves the anchor so that the field
point under that screen point does not move**. Looking closer at a dune does not
slide the dune away. The property is exact arithmetic — the anchor after a push
is the field point under the cursor plus the old offset scaled by the inverse
factor — and it has a test with random lenses, random cursor points, and random
factors, because every later camera feature is a chance to break it silently.

**Adjustable means all of it.** A lens can be dragged by its edge to another
place on the screen, resized by its corner, panned by dragging inside it,
pushed by the wheel, switched to another layer, added, and closed. The list of
lenses is what the player has arranged, and the viewer draws them in list order
so that a later lens sits over an earlier one — which is how the cloud window
(issue 606) sits in a corner of the field.

Input goes to the lens under the cursor. Keyboard input goes to the lens that
was last clicked. A screen point that is under no lens goes to nothing; the
menu (issue 604) is not a lens and is asked first.

## Suggested implementation steps

1. Bring the `lenses` file in with `./new-source-file` and its companion. Export
   `new(layer, anchor_x, anchor_y, zoom, x, y, width, height)`, `push`,
   `to_screen`, `to_field`, `contains(lens, sx, sy)`, `field_extent(lens)` —
   the rectangle of field the lens can see, which the layer draws use to walk
   only visible cells.
2. Write the layer table as a separate numbered file, one row per layer, each
   row a draw function. The rows for the dunes and territory are issue 602's;
   units and patterns are this issue's; sightlines draws, for the unit last
   clicked, every cell it can see, lit, by asking issue 103's question per
   visible cell; the cloud row is issue 606's.
3. Write the lens list in the viewer: draw in order, hit-test in reverse order
   so the topmost lens under the cursor wins, and the adjustments — drag, resize,
   pan, push, switch, add, close — as a dispatch table on the input event.
4. The units layer draws each live unit's blended position (issue 601) as a
   mark in its team's colour, sized by the lens's zoom, with a short line for
   its facing along its current leg; the patterns layer draws every friendly
   factory's points as a line in the sand.
5. The test: `to_field(to_screen(p)) == p` for random lenses; after `push` at a
   random screen point, `to_field` of that point is unchanged within a tolerance;
   `contains` agrees with the rectangle; a lens with an unknown layer index is
   refused at construction.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the lens, and the layers it can show.
- [The tests come first](../docs/014-the-tests-come-first.md) — the exports the
  test assumes.
- Issue 601 (the snapshot pair every layer draws from), issue 602 (the ground
  and territory rows), issue 606 (the cloud row), issue 802 (the same lenses
  split across two screens).
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether a lens should be able to lock its anchor to a unit — following the
  truck, say — which is a small addition to the record and a question about
  whether following things is in this game's spirit at all.
- The zoom's bounds: a lens zoomed far enough out draws the whole field, and a
  lens zoomed far enough in draws one cell. Whether either end should be
  refused is a feel question for the proving ground.
