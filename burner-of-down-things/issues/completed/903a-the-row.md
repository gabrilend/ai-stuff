# 903a — The row

The first piece of 903: a row of the harness table (037) for `ollama`.

## Current Behavior

Built. `src/037-the-harness-table.lua`'s `harnesses.TABLE.ollama` holds
`needs = {"ollama"}`, `cost = "local"`, `pool = 2`, `limit = 120`, and a
`command(project, turn)` that runs `ollama run <turn.model>` with the
prompt on standard input, the same shape as the other rows. It refuses a
turn with no `turn.model` named, naming the field — resolving that name is
903c's own piece. Checked by `tests/078-checking-the-ollama-row.lua`.

## Intended Behavior

A row `ollama` in 037's `harnesses.TABLE`: `needs = {"ollama"}`, `cost =
"local"`, `pool`/`limit` defaults sized for one machine's own GPU, and
`command(project, turn)` building the shell line that runs the configured
model against the turn's prompt.

## Suggested Implementation Steps

1. The row's static fields. Done. 2. `command()` building the line. Done.
   **Test:** `harnesses.TABLE.ollama` has every field 037's other rows
   have. Done.

## Blocked by

None
