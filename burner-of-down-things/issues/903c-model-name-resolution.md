# 903c — Model name resolution

The third piece of 903.

## Current Behavior

No setting says which model `ollama` should run.

## Intended Behavior

The model is named in the case, or failing that the switchboard's own
settings (docs/068). An unnamed model is a refusal, naming what is
missing — never a silent default model.

## Suggested Implementation Steps

1. The case-level setting read. 2. The switchboard-settings fallback.
   **Test:** a case naming a model wins over the switchboard default;
   neither present is refused, naming what is missing.

## Blocked by

- 903a
