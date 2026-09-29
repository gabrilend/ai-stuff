# 801b — Canvas overrides

The second piece of 801: a canvas may override the look, but only by a name
the look table already owns.

## Current Behavior

Built. `src/070-the-look.lua`'s `with_overrides(overrides)` takes `defaults()`
and lays the given fields on top, by name; every name is checked against
`FIELDS` before any of them are merged, so a refusal never leaves a
half-applied look. An unknown name is refused, naming every legal field.
Checked by `tests/099-checking-canvas-overrides.lua`.

## Intended Behavior

A canvas may override any of 801a's fields by name (e.g. `ground = "gray"`
for one asset); an unknown name is refused, naming the legal fields.

## Suggested Implementation Steps

1. An override-merge function that checks every override name against
   801a's own keys before merging. Done: `070-the-look.lua`'s
   `with_overrides`. **Test:** an override of `ground` succeeds and is
   visible in the merged look; an override of an invented name is
   refused, naming the legal fields. Done.

## Blocked by

- 801a
