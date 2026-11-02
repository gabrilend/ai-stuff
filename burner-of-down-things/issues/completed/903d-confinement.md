# 903d — Confinement

The fourth piece of 903.

## Current Behavior

Built. The `ollama` row runs the model inside `src/138-one-answer.lua`,
which keeps only what the model prints on standard output and prints it
as `{"answer": ...}`; the turn's shell line writes that to `result.json`.
The model's standard error goes to `stderr.txt` and its exit status to
`exit`; nothing else is written. Checked by
`tests/140-checking-ollama-confinement.lua` with a stand-in model.

## Intended Behavior

The row answers one question per turn and writes nothing but its answer;
the machine (not the model) writes that answer into the turn folder. The
model has no file tools to confine in the first place, so this is simpler
than `claude_directories`/`claude_settings` (037), not their equivalent.

## Suggested Implementation Steps

1. The single-answer turn wrapper: call the model, capture standard
   output only, write it as the turn's result. **Test:** whatever the
   model prints to standard output becomes the turn's `result.json`
   answer field; nothing else on disk changes. Done.

## Decisions

- The wrapper is its own small script (138), run by the row as
  `luajit 138-one-answer.lua ollama run <model> < prompt.md`, so the
  row's command still reads as the model call it wraps (903a's check of
  the command is unchanged).
- The answer is what the model printed, byte for byte, untrimmed; JSON's
  control characters, quotes and backslashes are escaped, other bytes are
  written as they came (the model's own UTF-8 passes through).
- The model's exit status is the turn's. A model that fails still has what
  it printed kept as the answer, so a person can read why.
- The wrapper sits beside 037 and is found from 037's own folder, made
  absolute, so it is found from any working folder.
- The row now also needs `luajit` (for the wrapper) and `timeout` (as
  every row's shell line uses it).

## Blocked by

- 903a
