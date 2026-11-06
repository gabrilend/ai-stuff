# 136-the-machine-drawn.lua

The machine drawn by itself (docs/067, issue 805d): adapters from the
machine's own things to the canvas words' data. Reads no file; callers hand
in the graph, center or ledger lines they read.

| Function | In | Out |
|---|---|---|
| `blueprint_diagram(g)` | a blueprint graph (043's `build`) | `diagram`'s spec (134): one box per issue, named by its id, showing `"id name"`; one arrow from each blocker to the issue built on it |
| `center_chart(c, n, kind)` | a center (058's `compute`); how many (default `CENTER_BARS`, 8); a chart kind (default `bars`) | `chart`'s spec (074): the heaviest weights, heaviest first, labelled by their `about`. Refuses a center with no weights |
| `ledger_chart(lines, kind)` | ledger lines (016's `read`); a chart kind (default `bars`) | `chart`'s spec: how many lines of each kind, most first, ties by name. Refuses no lines |
