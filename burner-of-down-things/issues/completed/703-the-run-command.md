# 703 — The run command

One command that does whatever a case is waiting for, start to end —
*continue until it's built, as the harness would be designed to do.*

## Current Behavior

Built as `src/059-running.lua`, with the `run` command in `src/061-the-center-commands.lua`. Held requests are the person's: `run` never passes the hold and does not count a held request as waiting, and while an issue stays build-failed `run` does not build again (it would fail the same way). Checked by tests/062 (a surveyed case waits for describe, build, update; one run does all three; a second run changes nothing; a foundation request is held and then left to the person) and through the launcher in the phase 7 demo.

## Intended Behavior

**Command `run`**: from the ledger alone, decides what is waiting and does
it in order, stopping at the first step that cannot finish:

| The ledger lacks | Step |
|---|---|
| `surveyed` | survey (204) |
| `outlined`, or `described` for some outline row | describe (404) |
| `built` for some issue, and nothing is held from a failure | build (503) |
| `request-done` for some received request | update (603), without `--go` |

It prints each step as it starts and the goodbye at the end. Running it
again after it finished does nothing and says so.

## Suggested Implementation Steps

1. **Test:** a fresh fixture case with the stand-in goes to `delivered` in
   one `run`.
2. **Test:** a second `run` runs no turns.
3. **Test:** dropping a request into `input/` and running again handles only
   the request.

## Blocked by

- 702
