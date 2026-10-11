# 503 — The next-purchase vote

**Phase:** 5 — The round table
**Blocked by:** 502

**Blocks**: 504, 505
**Related documents:** docs/datapath-team-vote.md

## Current Behavior

Purchases are made by whoever presses the button.

## Intended Behavior

- Candidate purchases (factories, upgrades, unlocks — whatever the budgets
  can buy) are listed on a rim sector set. Each seat spreads support across
  candidates; support is scaled by that seat's priority weight for purchases.
- At each vote, the top-scored candidate is bought from its category when
  affordable; if not yet affordable it stays at the top and waits.
- The tally is shown: each candidate's score as a readout, and which seats
  supported it in their colors.

## Suggested Implementation Steps

1. Candidate list from the treasury's categories.
2. Score tally (data) and the support ring (view).
3. Tests: ties broken by a stated rule (lowest price, then oldest candidate).
