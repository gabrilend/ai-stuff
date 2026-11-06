# 802 — The paintbrush and its wall

The shared machinery every end uses: a canvas is a Lua file of plain data; its words are checked against a closed list; every error is found in one pass, named, located, and given the nearest legal word ([067](../docs/067-datapath-the-studio.md)).

## Current Behavior

Built. `src/151-the-wall.lua` loads a canvas with an empty environment
except the paintbrush's constructors, collects every unknown word or
field, wrong type, missing field and dangling reference with its line and
the nearest legal word, and reports them together; compiles names to
numbers into flat parallel arrays; and generates the paintbrush's
document, committed as `docs/paintbrush-png.md`. Checked by
`tests/152-checking-the-wall.lua`.

## Intended Behavior

- A canvas loads with an empty environment except the paintbrush's own constructors (`line{…}`, `surface{…}`, `arrow{…}`, …): the language is the parser, and the table of constructors is the grammar.
- The wall: every unknown word, unknown field, wrong type and dangling reference is collected, each with where it is and the nearest legal word by edit distance, and all reported together. Nothing is quietly filled in; an absent optional field takes the default the paintbrush document publishes.
- Compilation resolves every name to a number once (a box named `store` becomes an index), into flat parallel arrays.
- The paintbrush document is generated from the constructor table, so the two cannot drift.
- The seed is a named field of the canvas; its default is published.

## Suggested Implementation Steps

1. The loader and the wall. **Test:** a canvas with three mistakes gets three findings in one run, each with a line number and a suggestion. Done.
2. Compilation to flat arrays. **Test:** a reference to a missing name is a finding, not a crash. Done.
3. The generated document. **Test:** every constructor and field appears in it. Done.

## Decisions

- The wall is generic over a paintbrush table; `PNG` is the first, with
  docs/067's `.png` words: `canvas`, `line`, `surface`, `arrow`, `label`,
  `grid`, `chart`, `diagram`. `ground` is not a word of its own: it is
  spelled through the look (`canvas{ look = { ground = "gray" } }`), so
  the ground has one place.
- `canvas{}` is required exactly once, holding the category (checked
  against docs/010 question 14's list), size, seed (default 1) and look.
- Names: a surface may be named; an arrow's `from` and `to` are a point
  or a surface's name, resolved to its number once at compile, the
  arrow's end at the surface's middle. A missing name is a finding with
  the nearest real name, and the arrow's index is left 0.
- Defaults the document publishes but the look supplies (a line's weight,
  a surface's flair, every colour's palette ink) are named as such in the
  document ("from the look", "the palette's ink"), so nothing is filled
  in that the document does not say.
- The look is checked through 801d's `for_canvas`, so a day look on a
  night-only category is one more finding, not a crash. This is why the
  branch stacks on 801's.
- Sandboxing a canvas: empty environment, bytecode refused, strings
  without methods while it runs, the JIT off for it and a ceiling of
  1,000,000 instructions, so a canvas can only be data.
- Every finding of both passes is reported together, sorted by line.
- The document is committed as `docs/paintbrush-png.md`, and a check
  fails if it differs from what the table generates.
- `chart` and `diagram` are checked and carried as data here; their
  geometry is 074's and 134's.

## Blocked by

- 801
