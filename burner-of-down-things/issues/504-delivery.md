# 504 — Delivery

Saying the design is done, with the fingerprint of how it was made
([007](../docs/007-datapath-the-design.md), *delivered*).

## Current Behavior

A build ends without saying whether the design is complete.

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
