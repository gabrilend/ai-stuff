# 901c — Number issuance

The third piece of 901.

## Current Behavior

Nothing tracks which numbers have been given out.

## Intended Behavior

Numbers are given by the machine, always one more than the highest
recorded in the ledger — never chosen by whoever writes the tag.

## Suggested Implementation Steps

1. A "highest recorded number" reader over the ledger (016's `read`).
2. The next-number function. **Test:** the next number is one more than
   the highest recorded; an empty ledger's next number is 1.

## Blocked by

- 901b
