# 903c — Model name resolution

The third piece of 903.

## Current Behavior

The switchboard-wide half exists: `src/090-switchboard-settings.lua` holds
`router_model` (docs/010 open question 12's groundwork — it does not pick
a model, only builds the slot). The case-level setting, the fallback
order between the two, and the refusal when neither is present are not
yet built — this piece is still open.

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
