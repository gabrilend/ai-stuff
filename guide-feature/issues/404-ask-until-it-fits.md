# 404 — Ask until it fits

phase 4, the turn

## Current behavior

The fit check (105) can measure a reply and write a report. Nothing gives
the report back to a model.

## Intended behavior

The owner: "if their output doesn't fit it is returned mechanically and run
again with a description of why. Like a compiler error."

1. Ask the role's endpoint (401) with the conversation (403).
2. If the reply is a look call, answer it (503; until then, answer that the
   look tool is not built yet), add both to the conversation, and ask again,
   up to the look limit.
3. Run the fit check against the base canvas and the budgets.
4. If it fits, return the rows.
5. If not, add the reply (`assistant`) and the report (`user`) to the
   conversation and ask again.
6. After the last allowed try, end the turn with a give-up. Nothing is
   trimmed.

Counted per turn: tries, problems by kind, look calls, tokens, seconds.

## Suggested implementation steps

1. The loop, tested first with a scripted stand-in model (too wide, then
   fits; too many changes forever).
2. Then against kuvalu's llama.cpp server with a small canvas, to watch a
   real model being corrected.

## Related documents

- `docs/fit-check.md`
- `docs/datapath-voice-turn.md`, steps 5–6

## Blocked by

105, 401, 403.

## Blocks

405, 601.
