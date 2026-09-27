# 065-re-abstraction.lua

Finds the part at fault behind a failing workflow (issue 507): narrow first,
wider only when the narrow look finds nothing, narrow again to fix.

| Function | In | Out |
|---|---|---|
| `search(project, case, failure, target, options)` | paths table; case; `{ workflow, output }`; what the design should be; pool options | `{ fixed (boolean), turns (number), path (array of sentences: "audit 201: changed", "inspect 201+301: 201") }`. Each covered issue audited alone in seeded order (a design checksum before and after says whether it changed; after a change the workflow runs again, and passing ends the search); if something changed but it still fails, one more narrow pass; then inspections up the ladder; the first part named is audited again with the finding. Appends `audited` and `inspected` lines. A breach raises an error |
| `shuffle(items, seed_hex)` | array; hex string (the ledger's head) | a new array in a seeded order — the same history gives the same order |
| `ladder(order)` | shuffled ids | levels of groups after the singles: pairs (an odd one out left out), pairs of pairs, …, ending with one group of every id |
