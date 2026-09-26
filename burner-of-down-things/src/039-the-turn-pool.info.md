# 039-the-turn-pool.lua

Runs prepared turns together and judges each.

| Function | In | Out |
|---|---|---|
| `run_set(project, case, turns, options)` | paths table; case table; turn tables; `{ harness, size, limit, center }` (all optional) | array per turn `{ turn, verdict ("kept" \| "failed" \| "breach"), exit (number or nil), changes (charged to it), why (string) }`, and `{ breaches, shared, source_touched }` |

Order: write each turn's instructions; snapshot the case and source (reusing
`turns/snapshot.tsv`); append `turn-started` per turn; a pool of threads
takes shell lines from a channel until it is empty; snapshot again; compare
and charge; any change no turn may write makes every turn of the set a breach
(turns running together cannot be told apart) and appends `breach`; exit 124
or 137 is "ran past its limit"; append `turn-ended` per turn.
