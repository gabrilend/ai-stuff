# 072-the-txt-canvas.lua

The `.txt` end's canvas words (docs/067). `table` (807a), `list` and `tree`
(807b) are built; `box-diagram` and `prose` (807c-d) are later pieces that
will join this file.

| Function | In | Out |
|---|---|---|
| `table(rows)` | array of arrays of strings, one array per row | the rows rendered as space-padded columns (two spaces between), one line per row, widths measured in characters |
| `list(items)` | array of strings | items rendered one per line, each prefixed `"- "`; one level, so every bullet lands in the same column |
| `tree(root)` | a node: `{ text = string, children = {node, ...} }` (`children` optional at a leaf) | the node and its descendants, one line per node, depth-first, each level indented a fixed step deeper than its parent, no bullets |
| `char_width(s)` | a UTF-8 string | its length in characters, not bytes |
