# 074-the-chart-canvas.lua

The `chart` canvas word's geometry (docs/067). So far only `bars` (issue
805a); `lines` and `dots` (805b) share its axis geometry and will join this
file when built. Paints nothing itself — 804's painter draws the boxes this
returns; 801c's flair colours their midline.

| Function | In | Out |
|---|---|---|
| `bars(data, width, height)` | array of numbers; the chart's pixel box | array of bar boxes `{x, y, w, h}`, left to right, each height proportional to its value against the largest in `data` |
