# 903b — The needs check

The second piece of 903.

## Current Behavior

`harnesses.row()` checks a program is on the `PATH` (037's existing
behaviour); nothing checks the ollama *server* is answering.

## Intended Behavior

The needs check for `ollama` also asks the server for its models; with the
server stopped, `row("ollama")` refuses, naming it — never a quiet switch
to another harness (docs/068).

## Suggested Implementation Steps

1. The "ask for models" check. 2. Wiring it into `row()`'s refusal path.
   **Test:** with the server stopped, a turn using `ollama` is refused by
   name.

## Blocked by

- 903a
