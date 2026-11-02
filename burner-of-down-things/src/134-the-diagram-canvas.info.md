# 134-the-diagram-canvas.lua

The `diagram` canvas word's geometry (docs/067, issue 805c): boxes and
arrows laid out by levels with the blueprint graph's own `build` and
`levels` (043). An arrow from `a` to `b` makes `b` build on `a`, so it
always runs rightwards. Paints nothing itself — 804's painter draws what
this returns.

| Function | In | Out |
|---|---|---|
| `graph(spec)` | `{boxes = {{name, text}, ...}, arrows = {{from, to, there, here}, ...}}` (`text` defaults to the name; labels optional) | a 043 graph: one node per box, its `blocked_by` the boxes with an arrow to it. Refuses no boxes, a name that is not one word, a repeated name, an arrow naming no box (listing the boxes), an arrow from a box to itself, a circle of arrows |
| `layout(spec, width, height)` | as `graph`; the pixel box | `{columns, boxes = {[name] = {name, text, level, x, y, w, h}}, order, arrows = {{from, to, start, finish, there, here}}}`: one column per level, boxes in name order down each column; each arrow from the middle of its source's right edge to the middle of its target's left edge, `there` at the start and `here` at the finish |
| `on_edge(p, box, slack)` | a point `{x, y}`; a laid-out box; optional tolerance | whether the point lies on the box's outline |
| `BOX_SHARE` | | a box's share of its column's width and its row's height (0.6) |
