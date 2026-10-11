# 705 — Held choices strengthen their unlock

**Phase:** 7 — Growing outward
**Blocked by:** 704

**Blocks**: 706, 708
**Related documents:** docs/datapath-choices.md (held choice)

## Current Behavior

A choice not taken at the level-up is lost.

## Intended Behavior

- Any offered choice can be held instead of taken. Held choices sit in a
  rack on the wheel (small sectors on an inner ring).
- A held choice can be taken later at its price.
- A held choice that requires an unlock the side does not own waits. When
  that unlock is bought, each waiting held choice raises the unlock's
  strength (every choice under that unlock gets a stat multiplier).

## Suggested Implementation Steps

1. Held list per side; strength field on unlocks.
2. Strength applied to choices under the unlock when they are taken.
3. Tests: three held choices waiting on one unlock give the stated strength.

## Open questions

- Is this what "increases in power the thing it requires" means? (Open
  question 5.)
