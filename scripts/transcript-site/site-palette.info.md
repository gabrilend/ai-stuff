# site-palette.lua

Turns a palette file into the pages' colours.

## Public functions

- `load(path) -> colours, css` — reads a palette file and returns a table of
  CSS name to hex string, and the same as a `:root { }` block.
- `from_balance_table(table) -> colours` — the same from a table already
  loaded. Raises when a wanted colour is missing: a missing CSS colour
  renders as nothing, and text would go black on black.
- `to_hex({ r, g, b }) -> string` — one colour, channels 0 to 1, to `#rrggbb`.
- `custom_properties(colours) -> string` — the `:root { }` block.
- `WANTED` — the seven colours the pages use, as data: `strength`,
  `dexterity`, `constitution`, `intellect`, `spirit`, `background` (CSS
  `--ground`) and `plain_text` (CSS `--plain`).

## A palette file

A Lua file returning `{ palette = { <name> = { value = { r, g, b } }, ... } }`
with each channel a number from 0 to 1 — the shape of double-diaper-dungeon's
balance table, so that table works as a palette file too.
`default-palette.lua` is generated from it by `make-default-palette`.
