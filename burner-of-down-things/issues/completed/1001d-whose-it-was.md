# 1001d — Whose it was

The fourth piece of 1001.

## Current Behavior

Built. `103-the-story.lua`'s `whose(lines)` is the ledger-kind-to-actor
lookup (`ROLES`, `TURN_ROLES`): `case-opened`, `request-received` and
`held` are the person's; `surveyed`, `graded`, `delivered` and the
request outcomes are the machine's; a turn's work names its role and the
harness of the latest turn that plays it, read from the ledger's own
`turn-started` lines (`the builder (the stand-in)`, `the referee
(claude-code)`). Each chapter opens with a `Whose:` line naming everyone
in it once, and each sentence names who did that line. Checked by
`tests/106-checking-whose-it-was.lua`: a request's chapter names the
person as its author.

Decision: the harness is the finest grain the ledger records today (039
writes `<kind> <about> by <harness>`); a model's own name (903c's
`router-model`) is not on the ledger line, so it is not guessed here.

## Intended Behavior

Every chapter names whose each thing was — the person, the referee, the
builder, the stand-in or a named model — reading whose-work markers the
ledger already records.

## Suggested Implementation Steps

1. A ledger-kind-to-actor lookup. **Test:** a request's chapter names the
   person as its author. Done: `103-the-story.lua`'s `whose`.

## Blocked by

- 1001b
