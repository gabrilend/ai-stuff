<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of the team table's votes. Updated by phase 5 issues. -->

# Datapath: ballots to spending

## Data

| Structure | Fields |
|---|---|
| distribution ballot | `seat` (integer), `resource` (string: metal, glass or aether), `split` (table of category name → number, summing to 1: production, upgrades, heroes, reserve) |
| purchase ballot | `seat` (integer), `support` (table of candidate id → number, summing to 1) |
| priority weights | `seat` (integer), `weights` (table of ballot name → number, summing to the same total for every seat) |
| tally | per resource: the resulting split (table category → number); for purchases: candidate ids ranked by weighted support |

## Steps

```
 each seat edits its ballots and weights (any time) ─┐
 vote cadence reached (calendar complication) ───────┴─▶ tally
   distribution: for each resource,
       result split = Σ (seat weight for that resource × seat's split) / Σ weights
   purchase: score = Σ (seat weight for purchases × seat's support for candidate)
 ─▶ treasury income flows into categories per the split
 ─▶ the top-scored purchase is bought from its category when affordable
```

Every seat's weights sum to the same total, so no seat can care about
everything at once: caring a lot about glass means caring less about metal.
