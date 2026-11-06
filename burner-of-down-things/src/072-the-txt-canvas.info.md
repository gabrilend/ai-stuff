# 072-the-txt-canvas.lua

The `.txt` end's canvas words (docs/067). `table` (807a), `list` and `tree`
(807b), `box-diagram` (807c) and `prose` (807d) are built.

| Function | In | Out |
|---|---|---|
| `table(rows)` | array of arrays of strings, one array per row | the rows rendered as space-padded columns (two spaces between), one line per row, widths measured in characters |
| `list(items)` | array of strings | items rendered one per line, each prefixed `"- "`; one level, so every bullet lands in the same column |
| `tree(root)` | a node: `{ text = string, children = {node, ...} }` (`children` optional at a leaf) | the node and its descendants, one line per node, depth-first, each level indented a fixed step deeper than its parent, no bullets |
| `box_diagram(diagram)` | `{boxes = {{name, text}, ...}, arrows = {{from, to, there, here}, ...}}` (`text` defaults to the name; labels optional) | boxes left to right in ASCII lines (`+`, `-`, `|`), each three rows; beneath them one lane per arrow, in the order given: a `|` down from the source box's edge, the lane, a `^` under the target box, `there` on the lane by the source and `here` by the target. Each arrow end has its own column; the gap between boxes widens until every lane's labels fit clear of the verticals crossing it. Refuses an empty diagram, a box with no name or a repeated name, an arrow naming no box (listing the boxes), an arrow from a box to itself |
| `prose(template, data)` | a template string with `{{slot}}` marks (034's syntax: letters, digits, `_`); a table of values by slot name | the filled text; or nil and an array of findings, in order, when any slot has no value, an empty value, or a value that is not text or a number, or when a `{{` opens no slot mark. Never renders a blank |
| `char_width(s)` | a UTF-8 string | its length in characters, not bytes |
