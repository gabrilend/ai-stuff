# 504 — Delivery

Saying the design is done, with the fingerprint of how it was made
([007](../docs/007-datapath-the-design.md), *delivered*).

## Current Behavior

Built in `src/050-building.lua`: all issues built and a final full acceptance run passing writes `output/delivered` (design path, issues, turns spent on the case, the `delivered` line's number and hash) and appends `delivered`. A build run that builds nothing over an already-delivered design reports it delivered without appending a second `delivered` line — the ledger records events, and nothing happened. Checked by tests/052.

## Intended Behavior

At the end of the build step, when every issue in the graph is `built` and a
final acceptance run over all of them passes: `output/delivered` is written
(design path, issue count, turns spent on this case, ledger head hash) and a
`delivered` line appended. When not, goodbye
lists every held and failed issue.

## Suggested Implementation Steps

1. **Test:** the all-passing fixture ends with `delivered`; the failing one
   ends without it and its goodbye names the failed issue and its held reach.

## Blocked by

- 503
