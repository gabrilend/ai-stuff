# The src paintbrush

Generated from `src/153-the-source-end.lua`'s `SRC` table by
`wall.document()`; do not edit by hand (a check compares the two).
A canvas is a Lua file of these words and nothing else; a word or
field not here is refused, with the nearest legal one named.

## `canvas{ … }`

What the canvas is: a source file, with its seed. Every canvas has exactly one.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `category` | one of the studio's categories: card, chart, clip, diagram, note, source, still | required | always `source` for this paintbrush |
| `seed` | a whole number, 0 or more | `1` | the seed every random choice starts from |

## `source{ … }`

The one file to write. Every canvas has exactly one.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `language` | one of bash, c, javascript, lua | required | the file's language, a row of the language table |
| `version` | a string | required | the language's version, named on the file's first line |
| `purpose` | a string | required | what the file is for, in a sentence |
| `prompt` | a string | required | what the turn writing it is asked |
