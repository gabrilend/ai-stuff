# 302 — easing library

## Current Behavior

Complete, with one scope growth folded in deliberately: the fade
*envelopes* (the score's fade enum — hold, in, out, in-out, flash)
live here beside the motion easings, because both are small pure
curves over the same raw time-fraction and the validator wants one
address for vocabulary truth. The property test walks both whole
tables so a curve added later cannot forget its contract; lookups
refuse misspellings and teach the legal words back. Thirty-two
assertions.

## Intended Behavior

A small dispatch table of named easing curves: raw time-fraction in,
shaped progress out.

- The founding set: **linear**; **stroke** (slow start accelerating
  hard into the finish — the vision's brush gesture; implemented as a
  power-curve ease-in whose exponent is an aesthetic knob); **fade-in**
  (for tracks whose *intensity* rather than position ramps — easing
  applies to emitter strength there); **ease-out**; **smoothstep**.
- Curves are pure functions in a table keyed by name — adding one is
  adding a row, and the scene validator's list of legal names is
  *derived from this table*, never a second copy that can drift.
- Every curve maps 0 to 0 and 1 to 1 and stays within bounds; a
  property test enforces this for all registered names at once, so a
  new curve cannot forget the contract.

## Suggested Implementation Steps

1. The dispatch table and the founding five curves.
2. The property test over the whole table plus shape spot-checks
   (stroke's midpoint lands well below one-half; ease-out mirrors it).

## Related Documents

- docs/datapath-scene-script.md (easing in the compiled track)
