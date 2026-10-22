# 401 — Inference backends, and the local model

phase 4, the thinkers

## Current behavior

Nothing exists. Backends are designed in `docs/datapath-thinker.md`,
"Inference backends".

## Intended behavior

The table of inference backends, chosen by name in `input/thinker`, every
entry the same shape:

- **in**: a conversation (list of turns, each a role string `system`, `user`
  or `assistant`, and a text string) and the most tokens to produce (whole
  number);
- **out**: the reply text (string) and counts (tokens in, tokens out:
  whole numbers; seconds: decimal);
- **failure**: an error with a reason (no answer, refused, timed out, bad
  reply). Never an empty reply standing in for a failure.

This issue builds the table and its first entry, `local-llama`: a llama.cpp
server on the same machine's loopback address, reached over HTTP with
LuaSocket. It is tested on kuvalu against a llama.cpp server running a small
model, so phase 4 does not wait on the fg-sora machines.

A backend also answers "how long is your context, in tokens", because the
context gatherer (403) fills up to that budget. llama.cpp's server reports
it and can count tokens for a text, so the budget is measured, not guessed.

## Suggested implementation steps

1. Find or build llama.cpp on kuvalu (check `/home/ritz/programs/` and the
   minimal-llm and risc-v-ollama projects first, since both planned it).
2. The backend table and `local-llama`.
3. Tests against a running server: a reply, a timeout (server stopped), a
   context length and a token count.

## Related documents

- `docs/datapath-thinker.md`

## Blocked by

None.

## Blocks

402, 405.
