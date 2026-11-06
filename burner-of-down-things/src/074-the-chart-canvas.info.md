# 074-the-chart-canvas.lua

The `chart` canvas word's geometry (docs/067): `bars` (issue 805a),
`lines` and `dots` (805b), all over one shared axis geometry, `axes`.
Paints nothing itself — 804's painter draws what this returns; 801c's
flair colours a bar's midline.

| Function | In | Out |
|---|---|---|
| `axes(data, width, height)` | array of numbers (none negative, the largest positive); the chart's pixel box | `{n, largest, width, height, gap, slot, x(i), centre(i), y(value)}`: datum i's slot's left edge and middle, and the pixel row a value reaches (0 at the top) |
| `bars(data, width, height)` | as `axes` | array of bar boxes `{x, y, w, h}`, left to right, each height proportional to its value against the largest in `data` |
| `lines(data, width, height)` | as `axes` | `{points = {{x, y}, ...}, segments = {{x1, y1, x2, y2}, ...}}`: each point at its slot's middle and its bar's top; one segment between neighbours |
| `dots(data, width, height)` | as `axes` | `{{x, y, r}, ...}`: one dot where `lines` puts each point, radius `DOT_SHARE` of a slot |
| `chart(spec)` | `{kind = "bars"|"lines"|"dots", data, labels (optional, one per datum), width, height}` | `{kind, marks, labels = {{text, x}, ...}}`; refuses an unknown kind, naming the kinds, and labels that do not match the data |
| `KINDS`, `DOT_SHARE` | | the kinds in docs/067's order; a dot's radius as a share of its slot (0.15) |
