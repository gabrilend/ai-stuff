# 905c — Joint checking

The third piece of 905.

## Current Behavior

Built. `src/127-plans.lua`'s `check(plan, from, wanted)` checks every
joint — the first station takes `from`, each output is the next input,
the last gives `wanted` — and names the one that does not fit ("joint 2
does not fit: 'chart' gives 'canvas' but 'png-of-text' takes 'text'").
`run` calls it first and refuses with nothing run. Checked by
`tests/129-checking-joint-checks.lua`: a plan with one mismatched joint
is refused before its first station runs; a bad start and a bad end are
refused too. A plan `find` returns always fits; the check is for one the
router or a person hands over.

## Intended Behavior

Every joint (one station's output shape against the next one's input
shape) is checked before the first station runs; a joint that does not
fit is refused, named, and nothing runs.

## Suggested Implementation Steps

1. The joint-fit check over a found plan. 2. The refusal message naming
   the mismatched joint. **Test:** a plan with one mismatched joint is
   refused before its first station runs. Done: `check`.

## Blocked by

- 905b
