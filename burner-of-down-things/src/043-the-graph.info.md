# 043-the-graph.lua

Which issue builds on which. A **node**: `id`, `name` (strings),
`blocked_by`, `blocks`, `covers` (arrays of strings), `level` (number: 0
for none blocking, else one more than the highest blocker).

| Function | In | Out |
|---|---|---|
| `build(rows)` | checked outline rows | `{ nodes = {id → node}, ids = sorted ids }` |
| `levels(graph)` | graph | arrays of ids per level, level 0 first — the build order |
| `reach(graph, ids)` | graph; ids | those ids plus everything built on them, sorted — what a change to them forces to be rebuilt |
| `text(graph, marks)` | graph; optional id → mark | the levels as text, for a person |
