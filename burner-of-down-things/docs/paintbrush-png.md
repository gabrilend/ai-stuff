# The png paintbrush

Generated from `src/151-the-wall.lua`'s `PNG` table by
`wall.document()`; do not edit by hand (a check compares the two).
A canvas is a Lua file of these words and nothing else; a word or
field not here is refused, with the nearest legal one named.

## `arrow{ … }`

A line from one place to another, its head at the far end, a label at either end (there — here).

| Field | Type | Default | Meaning |
|---|---|---|---|
| `from` | a point `{x, y}`, or the name of a named surface (its middle) | required | where it starts |
| `to` | a point `{x, y}`, or the name of a named surface (its middle) | required | where its head is |
| `there` | a string | `""` | the label at its start |
| `here` | a string | `""` | the label at its head |
| `colour` | `{r, g, b}` or `{r, g, b, a}`, each 0-255 | the palette's ink | the palette's ink when absent |

## `canvas{ … }`

What the canvas is: its category, size, seed and look. Every canvas has exactly one.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `category` | one of the studio's categories: card, chart, clip, diagram, note, source, still | required | what kind of asset |
| `width` | a whole number, 1 or more | `640` | pixels across |
| `height` | a whole number, 1 or more | `360` | pixels down |
| `seed` | a whole number, 0 or more | `1` | the seed every random choice starts from |
| `look` | the look's own fields by name (070): ground, palette, flair, line_weight, arrow, flair_shift | `{}` | the look's fields this canvas changes (070); a day palette is refused for a night-only category |

## `chart{ … }`

A chart over axes (074's geometry).

| Field | Type | Default | Meaning |
|---|---|---|---|
| `kind` | one of bars, lines, dots | `"bars"` | how the data is drawn |
| `data` | `{n, …}`, one number or more | required | the values |
| `labels` | `{"…", …}`, strings | `{}` | one per value, or none |
| `at` | `{x, y}`, two numbers, in pixels from the top left | `{0, 0}` | its top left |
| `size` | `{x, y}`, two numbers, in pixels from the top left | the canvas's size | its width and height; the whole canvas when absent |

## `diagram{ … }`

Boxes and arrows laid out by level (134's geometry).

| Field | Type | Default | Meaning |
|---|---|---|---|
| `boxes` | `{{name = …, text = …}, …}`, one box or more, each named | required | the boxes, each named |
| `arrows` | `{{from = …, to = …, there = …, here = …}, …}`, each naming two boxes | `{}` | each from one box to another |

## `grid{ … }`

Faint lines across the whole canvas, every `step` pixels.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `step` | a whole number, 1 or more | `40` | pixels between lines |
| `weight` | a number | `1` | pixels wide |

## `label{ … }`

Text at a point.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `text` | a string | required | what it says |
| `at` | `{x, y}`, two numbers, in pixels from the top left | required | its top left |
| `size` | a whole number, 1 or more | `16` | pixels tall |
| `colour` | `{r, g, b}` or `{r, g, b, a}`, each 0-255 | the palette's ink | the palette's ink when absent |

## `line{ … }`

A straight line.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `from` | `{x, y}`, two numbers, in pixels from the top left | required | where it starts |
| `to` | `{x, y}`, two numbers, in pixels from the top left | required | where it ends |
| `weight` | a number | from the look | pixels wide; the look's line_weight when absent |
| `colour` | `{r, g, b}` or `{r, g, b, a}`, each 0-255 | the palette's ink | the palette's ink when absent |

## `surface{ … }`

A filled polygon; with a name, arrows can point at it.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `points` | `{{x, y}, …}`, three points or more | required | its corners, in order |
| `name` | a name: letters, digits, `-` and `_`, starting with a letter | none | what arrows call it |
| `colour` | `{r, g, b}` or `{r, g, b, a}`, each 0-255 | the palette's ink | the palette's ink when absent |
| `flair` | one of on, off | from the look | the flair on its midline; the look's flair when absent |
