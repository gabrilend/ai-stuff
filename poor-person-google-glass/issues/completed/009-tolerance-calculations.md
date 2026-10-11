# 009 — Tolerance calculations

**Phase:** 0 — Tools
**Related documents:** docs/tolerances.md, docs/sizes.md

## Current Behavior
Built. Format: docs/tolerances.md; reference sizes: docs/sizes.md. Code:
`src/019-a-calculation-and-its-checks.lua` (load and check, every problem at
once), `src/020-working-out-tolerances.lua` (nominal, worst case over all
corners and the middle, spread, shares, verdicts),
`src/021-the-tolerance-report.lua` (reads only the results file),
`src/022-calculate.lua` and the `calculate` script; tests in
`src/023-the-tolerance-tests.test.lua`. Six calculations in
input/calculations/.

Two changes to the first plan, found by working the six through:
- The spread first took half of each input's low-to-high change. For an
  answer that is a size (always positive) that change cancels, and a
  +/-0.05 degree tilt showed no spread at all. Each input's effect is now
  the larger of its two one-sided changes from the middle, and answers that
  can be off either way keep their sign, with a limit on each side.
- "What to tighten first" said temperature, which nobody can tighten.
  Inputs may be marked `condition = true` (temperature, the wearer's eyes);
  the report lists them apart, as what the design must absorb.

The limits are guesses (open question 14 in docs/open-questions.md). For
where each calculation stands, run `./calculate`.

## Intended Behavior
The owner: "Maybe we could do some material tolerances calculations, just
to get the format that we want to use down pat? We haven't gotten the thing
modelled yet, but we can at least guess at the formulas and have them
pre-built for when we need to calculate stuff."

**The format.** One calculation per file in input/calculations/, returning:
- `question` (string): what it answers, in plain words;
- `inputs`: a list, each { name (string), nominal (number), unit (string
  from a closed list), minus, plus (numbers ≥ 0: how far below and above
  the nominal it may be), from (string: where the number came from — a
  datasheet, docs/sizes.md, or "guess") };
- `outputs`: a list, each { name, unit, and a limit: at_least or at_most
  (number), or none };
- `compute(v)`: inputs by name → outputs by name (numbers).

**The engine.** For each output: the nominal value; the **worst case**
(every input at every combination of its extremes — exact when the formula
only rises or falls with each input, as stack-ups do); the **statistical
spread** (root-sum-square of each input's own effect, i.e. tolerances
treated as independent); each input's share of the spread (what to tighten
first); and pass/fail against the limit for both. No randomness: the same
file gives the same answer.

**Kept apart:** working out writes a results file
(output/calculations/NAME.results.lua); a separate step reads only that and
writes the report (NAME.report.md). A `calculate` script runs both and says
goodbye with counts of passes and fails.

**Pre-built formulas**, guesses until the parts are designed, sized like a
Google-Glass-style device (docs/sizes.md):
1. tab channel clearance — does a tab still swing freely in its channel
   from cold to warm?
2. index match reflection — how much light each liquid/glass boundary
   reflects as the liquid's index drifts with temperature.
3. two-eye vertical alignment — how far apart the two eyes' pictures land
   vertically when the tile mirrors tilt by their tolerances.
4. hydraulic reach drift — how far the panel arm creeps as its sealed fluid
   warms.
5. eye position fit — does one frame size put the tiles in front of the
   pupils across the range of eye spacings?
6. pipe and band expansion — how much the glass light pipe and the band
   holding it change length differently with temperature.

## Suggested Implementation Steps
1. docs/sizes.md (reference sizes) and docs/tolerances.md (the format).
2. src: quantities and their checks; the engine; the report; the program.
3. `calculate` script; the six calculations; tests (a linear stack's worst
   case is the sum of tolerances and its spread the root-sum-square).
