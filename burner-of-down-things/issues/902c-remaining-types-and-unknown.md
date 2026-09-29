# 902c — Remaining types, and `unknown`

The third piece of 902.

## Current Behavior

902a and 902b cover eight of the eleven closed types.

## Intended Behavior

Recognisers for `source` (027's language table says it is code), `program`
(executable bit or a shebang), `results`/`finding`/`request` (the
machine's own JSON/markdown shapes). Anything matching none of the closed
list is `unknown` — never a guess.

## Suggested Implementation Steps

1. The remaining five recognisers. 2. The `unknown` fallback. **Test:**
   an unknown thing is `unknown`, never assigned a guessed type.

## Blocked by

- 902a
- 902b
