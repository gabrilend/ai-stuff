# 058-the-center.lua

The personality: weights from the ledger alone. A **center**: `weights`
(about → number), `last` (about → the kind that last added to it), `lines`
(number), `head` (string).

| Function | In | Out |
|---|---|---|
| `compute(lines)` | ledger lines | a center: before each line every weight × `BALANCE.keep` (0.97); the line's `about` + `BALANCE.weights[kind]`; a `graded` line adds `graded_per_issue` (1) to each touched id |
| `heaviest(center, n)` | | the n heaviest `{ about, weight, last }` |
| `paragraph(center, case)` | | the five heaviest in words, for every turn's instructions |
| `order_requests(center, waiting, index)` | | waiting requests by their own weight plus their touched issues' weights; ties oldest first |
| `order_ids(center, ids)` | | ids heaviest first; ties by id |
| `options_for(case)` | case | `{ pool = { center = paragraph }, order, build_order }` — what every step takes from the center, recomputed when asked |
| `write_view(case, center)` | | `center.txt` (a view the machine never reads back); returns its text |
| `BALANCE` | | the numbers; changes go to docs/balance-updates.md |
