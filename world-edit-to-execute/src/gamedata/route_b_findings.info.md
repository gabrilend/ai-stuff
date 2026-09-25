# route_b_findings.lua

Data only. It holds the disagreements between the routes that were
investigated by hand, keyed `"id.Table.column"` (string) → `{ kind (string),
why (string, the evidence) }`. A matching row gets the verdict `explained`.
The game's number is never changed.

| Kind | Meaning |
|------|---------|
| `researched` | The page shows the value after research (the Druid forms). |
| `wiki_error` | The page was wrong at the time; `why` gives the evidence. |
| `other_form` | The page's numbers belong to another form of the unit (the Spirit Walker). |

Upgrade-chain costs and pages written after 1.30 need no entry, because
`route_b.lua` works them out itself.

Issue: `issues/112e-route-b-published-values-cross-check.md`
