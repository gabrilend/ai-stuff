# 905c — Joint checking

The third piece of 905.

## Current Behavior

905b finds a chain; nothing checks it fits before running.

## Intended Behavior

Every joint (one station's output shape against the next one's input
shape) is checked before the first station runs; a joint that does not
fit is refused, named, and nothing runs.

## Suggested Implementation Steps

1. The joint-fit check over a found plan. 2. The refusal message naming
   the mismatched joint. **Test:** a plan with one mismatched joint is
   refused before its first station runs.

## Blocked by

- 905b
