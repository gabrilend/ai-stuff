# 903c — Model name resolution

The third piece of 903.

## Current Behavior

Built. `src/090-switchboard-settings.lua`'s `resolve_model(project,
record)` reads a case's own `<folder>/router-model` file (one line) first,
falls back to the switchboard's own `router_model` setting, and refuses
when neither names one, naming both places checked. Checked by
`tests/097-checking-model-resolution.lua`. Still no model is actually
chosen anywhere (docs/010 open question 12) — this piece only builds
where that choice will be read from, on both the case and switchboard
side.

## Intended Behavior

The model is named in the case, or failing that the switchboard's own
settings (docs/068). An unnamed model is a refusal, naming what is
missing — never a silent default model.

## Suggested Implementation Steps

1. The case-level setting read. Done: a `router-model` file in the case's
   own folder. 2. The switchboard-settings fallback. Done. **Test:** a
   case naming a model wins over the switchboard default; neither present
   is refused, naming what is missing. Done.

## Blocked by

- 903a
