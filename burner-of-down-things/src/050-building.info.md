# 050-building.lua

Builds the blueprint into the design, level by level.

| Function | In | Out |
|---|---|---|
| `step(project, case, options)` | paths table; case table; `{ rebuild = ids, order = function(ids) → ids, pool = pool options, limit = acceptance seconds }` | a **report**: `built`, `failed`, `held` (arrays of ids), `held_why` (id → reason), `turns`, `waves`, `repairs` (numbers), `delivered` (boolean), `head` (the ledger head at delivery), `already` (true when nothing new was built over an earlier delivery) |
| `target_text(case)` | case table | what the design should be: the person's words, or "the same kind of software … written in <the survey's main language>" |

Per level: the wanted, unheld issues whose blockers are all built are one
set of build turns; each is checked by its acceptance; failures get up to 2
repair turns shown the failing command and output; still failing →
`build-failed` and the reach held. After each level every built issue's
acceptance runs again and anything a later build broke is repaired. All
built and a final full run passing → `delivered` and `output/delivered`.
Issues that could not be described hold their reach from the start. A
breach raises an error.

Referees (issue 506): before the first wave, if the case has no `refereed`
line, the workflows are written from the blueprint. Delivery needs them: a
case whose referee failed is not delivered. After every issue's own
acceptance passes, every workflow runs in the design; a failing workflow's
name and output go to repair turns for every issue it covers, up to 2
rounds; still failing → `workflow-failed` per workflow, not delivered. The
report gains `refereed`, `referee_turns`, `workflow_failures`.
