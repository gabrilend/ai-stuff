# 702 — Two-step roll tables

**Phase:** 7 — Growing outward
**Blocked by:** 701

**Blocks**: 703, 708
**Related documents:** docs/datapath-choices.md (two-step rolling)

## Current Behavior

There is no way to draw choices.

## Intended Behavior

- A roll table is a list of entries. Each entry has a roll chance (how likely
  it comes up at all when the table is walked) and a list of values (choice
  ids) each with a selection weight.
- Rolling: walk the entries; for each, roll its chance; if it comes up, pick
  one of its values by weight. Repeat walking until the requested count is
  reached.
- The tables themselves are generated from the catalog and the seed (which
  choices group into which entry, and the percentages).
- A table can be inspected: expected frequency of every choice, computed
  exactly from the percentages (not by sampling).

## Suggested Implementation Steps

1. `src/NNN-roll-tables.lua`: table generation and rolling (data only).
2. Exact-expectation calculator.
3. Tests: over many rolls (run across worker threads) observed frequencies
   match the calculator within tolerance.
