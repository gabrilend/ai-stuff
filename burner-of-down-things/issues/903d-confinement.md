# 903d — Confinement

The fourth piece of 903.

## Current Behavior

Nothing constrains what an `ollama` turn may write.

## Intended Behavior

The row answers one question per turn and writes nothing but its answer;
the machine (not the model) writes that answer into the turn folder. The
model has no file tools to confine in the first place, so this is simpler
than `claude_directories`/`claude_settings` (037), not their equivalent.

## Suggested Implementation Steps

1. The single-answer turn wrapper: call the model, capture standard
   output only, write it as the turn's result. **Test:** whatever the
   model prints to standard output becomes the turn's `result.json`
   answer field; nothing else on disk changes.

## Blocked by

- 903a
