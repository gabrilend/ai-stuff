# 901d — Reuse refusal

The fourth piece of 901.

## Current Behavior

A reused number is silently accepted.

## Intended Behavior

A parcel whose tag reuses a recorded number is refused, naming the first
use (case, ledger line); each new number is recorded in the ledger
exactly once.

## Suggested Implementation Steps

1. The reuse check against 901c's reader. 2. The ledger line recording a
   number's first use. **Test:** a reused number is refused, naming its
   first use; a fresh number is recorded once and accepted.

## Blocked by

- 901c
