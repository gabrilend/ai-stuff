# 903b — The needs check

The second piece of 903.

## Current Behavior

Built. `src/037-the-harness-table.lua`'s rows may carry a `serving()`
check; the `ollama` row's asks the server for its models (`ollama list`).
With the server stopped, `row("ollama")` refuses by name, quoting what
ollama said, saying how to start it, and saying no other harness stands
in. Checked by `tests/139-checking-the-ollama-needs-check.lua` with a
stand-in `ollama` on the PATH.

## Intended Behavior

The needs check for `ollama` also asks the server for its models; with the
server stopped, `row("ollama")` refuses, naming it — never a quiet switch
to another harness (docs/068).

## Suggested Implementation Steps

1. The "ask for models" check. 2. Wiring it into `row()`'s refusal path.
   **Test:** with the server stopped, a turn using `ollama` is refused by
   name. Done.

## Decisions

- The check is `ollama list`, which asks the server for its models and
  fails when it is not answering; it honours `OLLAMA_HOST` the same way
  `ollama run` does, so the check and the turn ask the same server.
- It is a new optional row field, `serving()`, so any later harness with a
  server can have one; `row()` runs it after the PATH check.
- The refusal names the harness, quotes what `ollama list` said (or its
  exit status when it said nothing), says how to start the server, and
  says no other harness is used in its place.
- The checks use a stand-in `ollama` program on the PATH, so no server or
  model is ever started by them.

## Blocked by

- 903a
