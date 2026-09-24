# Issue W07: Phase W Demo

**Phase:** W - WoW Client Bridge
**Type:** Integration / Demo (capstone)
**Priority:** Medium
**Dependencies:** W02, W03, W04, W05, W06

---

## Current Behavior

Demos exist for phases 0-5 (`issues/completed/demos/run_phase*.sh`, chosen
through `run-demo.sh`). None exists for phase W.

## Intended Behavior

`issues/completed/demos/run_phaseW.sh`, reachable from `run-demo.sh`, shows
numbers and pictures rather than descriptions:

- Conversion report for one WC3 map: ADT files written, placements, texture
  folds, unmapped units, unsupported natives; then the WoW client opened on
  that map.
- Our engine showing the same map with WoW models, with the replacement
  progress (override / client / placeholder) on screen.
- The latest comparison report (W04) opened in the browser.
- A forge gallery: one model before and after, per route (searched, generated,
  restyled).

Tools from earlier phases appear in new combinations: the phase 1 map parser
feeding the W02 converter, the phase 4 simulation driving W03's animation
states, phase 6 storage holding W05's candidates.

## Suggested Implementation Steps

1. Build each demo section as the matching issue completes.
2. Every section prints its statistics even if the proprietary client is
   missing, and says loudly which sections could not run and why.
3. Add the W entry to `run-demo.sh`.

## Acceptance Criteria

- [ ] `run-demo.sh` offers phase W
- [ ] Every section shows measured numbers from a real run
- [ ] Missing prerequisites are reported, never silently skipped

## Related Documents

- `docs/wow-client-bridge.md`
- `issues/phase-W-progress.md`
