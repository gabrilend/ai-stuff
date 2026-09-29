# 903 — The ollama harness

A row of the harness table (005) for a model running on this machine: light, free per call, for the router ([068](../docs/068-datapath-the-switchboard.md), *the router, and why it is light*).

## Current Behavior

ollama is installed (`/usr/local/bin/ollama`); its server is not running, and no model is chosen. 903a is built (issues/completed/903a-the-row.md): the harness-table row exists and runs `ollama run <turn.model>`, refusing a turn with no model named. 903b (the needs check), 903c (model name resolution) and 903d (confinement) are not yet built, so turns still run only through Claude Code or the stand-in.

## Intended Behavior

- The row `ollama`: needs `ollama` and a running server (checked by asking it for its models); cost `local`; the model named in the case or the switchboard's settings.
- It answers one question per turn and writes nothing but its answer, which the machine writes into the turn folder; confinement is the machine's own, since the model has no file tools.
- When the server is not running, the row refuses, naming it — never a quiet switch to another harness.

## Suggested Implementation Steps

1. The row and its needs check. **Test:** with the server stopped, a turn is refused by name.
2. One real question, run by hand when the owner starts the server and picks a model (docs/010).

## Sub-issues

- 903a — the row
- 903b — the needs check
- 903c — model name resolution
- 903d — confinement

## Blocked by

- 304
