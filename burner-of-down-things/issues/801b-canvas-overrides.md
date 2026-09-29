# 801b — Canvas overrides

The second piece of 801: a canvas may override the look, but only by a name
the look table already owns.

## Current Behavior

No canvas can override a look setting; 801a's table is fixed per project.

## Intended Behavior

A canvas may override any of 801a's fields by name (e.g. `ground = "gray"`
for one asset); an unknown name is refused, naming the legal fields.

## Suggested Implementation Steps

1. An override-merge function that checks every override name against
   801a's own keys before merging. **Test:** an override of `ground`
   succeeds and is visible in the merged look; an override of an invented
   name is refused, naming the legal fields.

## Blocked by

- 801a
