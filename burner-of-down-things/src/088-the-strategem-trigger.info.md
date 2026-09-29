# 088-the-strategem-trigger.lua

When a recurring mechanism is due for a strategem draft (docs/069, issue
1003a). Takes any mechanism-count table shaped like 1002d's own output, so
it does not need 1002d to be built. Writing the draft itself (1003b), the
one-file-per-mechanism drafts folder (1003c) and the person's own
promotion gate (1003d) are later pieces.

| Function | In | Out |
|---|---|---|
| `due(counts, drafted)` | `{[mechanism] = count}`; optional `{[mechanism] = true}` of ones already drafted | sorted array of mechanisms counted at least twice and not yet drafted |
| `RECURRENCE_THRESHOLD` | | `2` — how many times a mechanism must recur before it is due |
