# 805b — Line and dot charts

The second piece of 805.

## Current Behavior

Only bar charts (805a) exist.

## Intended Behavior

`chart{ kind = "lines" }` and `chart{ kind = "dots" }`, sharing 805a's axis
geometry: a line through the data's points, or one point per datum.

## Suggested Implementation Steps

1. The axis geometry factored out of 805a for reuse.
2. Line and dot drawing over it. **Test:** a line chart's points fall on
   the same axis positions 805a's geometry computes for the same data.

## Blocked by

- 805a
