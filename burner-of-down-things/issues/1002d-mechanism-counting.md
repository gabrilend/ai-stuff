# 1002d — Mechanism counting

The fourth piece of 1002.

## Current Behavior

Nothing counts how often a mechanism recurs.

## Intended Behavior

A growing list of mechanisms the machine counts (not judges) from
`lessons.md`, so recurrence is counted plainly — what 1003 reads to decide
when to draft a strategem.

## Suggested Implementation Steps

1. The mechanism-list reader over `lessons.md`. 2. The
   count-by-mechanism-text function. **Test:** the same mechanism in two
   cases counts two.

## Blocked by

- 1002b
