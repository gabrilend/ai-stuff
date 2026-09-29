# 802 — The paintbrush and its wall

The shared machinery every end uses: a canvas is a Lua file of plain data; its words are checked against a closed list; every error is found in one pass, named, located, and given the nearest legal word ([067](../docs/067-datapath-the-studio.md)).

## Current Behavior

There are no canvases.

## Intended Behavior

- A canvas loads with an empty environment except the paintbrush's own constructors (`line{…}`, `surface{…}`, `arrow{…}`, …): the language is the parser, and the table of constructors is the grammar.
- The wall: every unknown word, unknown field, wrong type and dangling reference is collected, each with where it is and the nearest legal word by edit distance, and all reported together. Nothing is quietly filled in; an absent optional field takes the default the paintbrush document publishes.
- Compilation resolves every name to a number once (a box named `store` becomes an index), into flat parallel arrays.
- The paintbrush document is generated from the constructor table, so the two cannot drift.
- The seed is a named field of the canvas; its default is published.

## Suggested Implementation Steps

1. The loader and the wall. **Test:** a canvas with three mistakes gets three findings in one run, each with a line number and a suggestion.
2. Compilation to flat arrays. **Test:** a reference to a missing name is a finding, not a crash.
3. The generated document. **Test:** every constructor and field appears in it.

## Blocked by

- 801
