# 007e — The describe script

**Phase:** 0 — Tools
**Parent:** 007
**Blocked by:** 007d

## Current Behavior
Built: `describe` in the project folder runs `src/016-describe.lua`, writes
output/described/NAME.gltf and NAME.report.md and the goodbye receipt, and
with --view opens the viewer. Examples: input/descriptions/drum.txt,
lamp.txt (the owner's phrasings), crown.txt (the panel arm along the
glasses' side arm, per the sixth round), glasses.txt (rectangular lenses,
asked for by the owner). The same description gives the same bytes: the
glTF writer now writes JSON keys in a fixed order (found by the test;
LuaJIT yields table keys in a different order each run).

## Intended Behavior
`./describe FILE [--view]`: reads a description, writes
output/described/NAME.gltf and NAME.report.txt (each part: kind, axis,
centre, extents in units of the first part, and the defaults it used), and
with --view opens the model in the viewer. Errors from the wall are printed
all together and nothing is written.

## Suggested Implementation Steps
1. `describe` in the project folder; example descriptions.
