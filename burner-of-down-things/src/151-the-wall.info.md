# 151-the-wall.lua

The paintbrush and its wall (docs/067, issue 802): a canvas is a Lua file
of plain data, loaded with an empty environment except the paintbrush's
constructors; the wall collects every mistake at once, each with its line
and the nearest legal word; compilation resolves names to numbers into
flat parallel arrays; the paintbrush's document is generated from the
same table (`docs/paintbrush-png.md`, checked to match).

A **paintbrush**: `{name, words = {[word] = {doc, once, required, order,
fields = {[field] = {type, required, default, doc}}}}}`. `PNG` is the
`.png` end's: `canvas`, `line`, `surface`, `arrow`, `label`, `grid`,
`chart`, `diagram`. A **finding**: `{line, word, message, suggestion}`.

| Function | In | Out |
|---|---|---|
| `read(text, brush, where)` | a canvas's text; a paintbrush (default `PNG`); its name for messages | the compiled canvas, or nil and every finding of both passes in line order |
| `read_file(path, brush)` | a canvas file | as `read` |
| `load(text, brush, where)` | as `read` | the words in canvas order, `{word, line, fields}` with defaults filled from the table, and the loading findings: unknown word, unknown field, wrong type, missing required field, a once-only word twice, a global set, a parse or run error, a runaway loop (`MOST_INSTRUCTIONS`), bytecode, no `canvas{}` |
| `compile(words)` | `load`'s words | `{canvas, look, names, order, xs, ys, lines, surfaces, arrows, labels, grids, charts, diagrams}` (each kind `{n, field = {…}}` in parallel), and its findings: a name given twice, a reference to no surface, a diagram arrow to no box, labels that do not match a chart's data, a look the category refuses (070's `for_canvas`, 801d) |
| `document(brush)` | a paintbrush | its Markdown document: every word in name order, every field with its type, default and meaning |
| `text(finding, where)` | a finding; a name | `"<where>:<line>: <word>: <message>; did you mean '<suggestion>'?"` |
| `nearest(word, names)` | a word; legal names | the nearest by edit distance, ties by name |
| `TYPES`, `CATEGORIES`, `PNG`, `MOST_INSTRUCTIONS` | | the field types; the studio's categories (docs/010 question 14); the `.png` paintbrush; 1,000,000 |
