# 905b — Shortest-chain search

The second piece of 905.

## Current Behavior

905a builds the shape graph; nothing searches it.

## Intended Behavior

Given a starting shape and a wanted shape, the shortest chain of stations
whose joints fit, found by search over the shape graph — no model
involved.

## Suggested Implementation Steps

1. A breadth-first search over 905a's graph. 2. The impossible-shape
   case, naming which type cannot be reached. **Test:**
   `integer-array + text → image` becomes `table → chart → png`; an
   impossible shape says which type cannot be reached.

## Blocked by

- 905a
