# 055-updating.lua

Handles waiting requests one at a time.

| Function | In | Out |
|---|---|---|
| `waiting(lines)` | ledger lines | array of `{ name, seq }`: received, not done or failed, oldest first |
| `step(project, case, options)` | `{ go, order = function(waiting) → waiting, build_order, pool, limit }` | array of `{ name, grade, outcome ("done" \| "held" \| "failed"), reach, report, why }` |

Per request: grade it if not yet graded (a locate that never answers fails
the request; a breach stops the run); at or above the case's `hold`
without `go` → `held` (recorded once); else amend, rebuild the reach taken
on the amended graph, and record `request-done` or `request-failed`.
