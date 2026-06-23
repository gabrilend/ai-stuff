# 10-056: Phase Demos — Compute Stats Live, Show What's Actually Built

## Status
- **Phase**: 10 (Developer Tooling)
- **Priority**: Medium
- **Type**: Feature / Maintenance
- **Status**: Open

## Background / Why This Exists

The phase demos (`demos/1-demo.sh` … `demos/6-demo.lua`, run via the
phase-picker) are part of the deliverable, not just a dev artifact — they are
how a visitor sees what the project does. Right now they have drifted: they
`echo` statistics as if they were facts, and those facts are stale. They also
describe functionality as it stood several phases ago, not as it is now.

## Current Behavior

- **Hardcoded stats echoed as truth.** Example, `demos/1-demo.sh`:
  `echo "• Poem extraction system processing 6,860+ poems"`. The corpus is now
  ~7,800 poems — the number is simply wrong, and nothing recomputes it.
- **Stale feature descriptions.** The demos narrate the pipeline as it existed
  when written; later phases (word cloud, source browser, explore pages,
  similarity/diversity work, the RAM-cache and llama.cpp changes) are under- or
  un-represented.
- **Truncated, illustrative output.** Calls like `lua src/poem-extractor.lua |
  head -20` followed by `[...output truncated...]` gesture at functionality
  rather than demonstrate a verifiable result. (Also note: `lua` is invoked
  where the project standard is `luajit`.)

## Intended Behavior

- **Every statistic is computed on the run, from the real data/tools**, so the
  number on screen is provably current. "7,816 poems" because it just counted
  them, not because someone typed it once. This matches the project rule:
  reference a validator/stat utility instead of baking numbers into prose.
- **Each demo showcases the functionality actually built for its phase**, and
  later phases get demos that reflect the tools they added (combining earlier
  phases' tools in new ways, per the demo philosophy). A reader should see the
  current system, not its fossil record.
- **Where possible, show the produced artifact**, not a description of it —
  e.g. open a generated HTML page, print a real validator summary, render a real
  word cloud slice. Visual/ִevidence-based over narration.

## Suggested Implementation Steps

1. Audit each demo against the current feature set: list what it claims vs. what
   exists now. Note every hardcoded number and every described-but-changed
   feature.
2. Replace each echoed statistic with a live computation that reads the real
   data or calls the real stat/validator tool, printing the number it just
   derived. Candidates already in the repo:
   - `scripts/validate-pipeline-data`, `scripts/validate-poem-representation`,
     `scripts/validate-poem-box-format`, `scripts/validate-diversity-cache`
   - the generators' own counts (poem total, word total, page counts) — the
     word-page run already logs e.g. "Built chronological mapping for N poems".
3. Refresh the narrative of each phase demo to the functionality that phase now
   provides, and add representation for the newer phases' tools (word cloud,
   source browser, explore pages, similarity/diversity, inference server).
4. Standardize on `luajit` (not `lua`) per project convention, and on the
   `${DIR}` setup the demos already use.
5. Keep the phase-picker entry point working; if a new phase demo is added,
   register it there.
6. If a stat is expensive to compute live, compute a cheaper exact proxy or
   clearly label any sampling — never print a trimmed number as if it were the
   whole (the "no silent caps" rule).

## Notes

- These are append-to over time as phases land; this issue is the reset that
  brings them current and makes them self-verifying. Treat it as the demo
  subsystem's baseline, not a one-off.
- Per the demo philosophy: focus on relevant statistics and real produced
  outputs over describing functionality in words.

## Related Documents / Tools

- The `scripts/validate-*` family — live stat/validation sources.
- `demos/1-demo.sh` … `demos/6-demo.lua`, `demos/generate-site.lua`, and the
  root phase-picker script.
- CLAUDE.md: demos are part of the deliverable; reference a stat utility rather
  than hardcoding numbers; show produced outputs (HTML in a browser, etc.).
