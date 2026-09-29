# 902d — The station table

The fourth piece of 902.

## Current Behavior

Recognisers exist (902a-c); nothing maps a shape to a station.

## Intended Behavior

The station table: one row per station — name, the shape it takes, the
shape it gives, and the command or step that runs it (a studio end, a
machine step, running a program) — and a shape-matching function.

## Suggested Implementation Steps

1. The table's rows for the stations that already exist (804's `.png`
   end, 807's `.txt` end, …). 2. The matching function. **Test:**
   `integer-array + text → image` finds the chart station; a shape no
   station gives is said plainly, not silently dropped.

## Blocked by

- 902c
- 804
- 807
