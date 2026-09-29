# 807b — Lists and trees

The second piece of 807.

## Current Behavior

Built, joined into `src/072-the-txt-canvas.lua` beside 807a's `table`.
`list(items)` prefixes each item `"- "`, one per line. `tree(root)` takes
`{text = string, children = {node, ...}}` and renders depth-first, each
level indented `TREE_STEP` (2) spaces deeper than its parent, no bullets —
a deliberate contrast with `list`'s flat, bulleted shape. Checked by
`tests/100-checking-lists-and-trees.lua`.

## Intended Behavior

Canvas words `list` (bulleted, one level) and `tree` (nested, indented by
depth), both plain text.

## Suggested Implementation Steps

1. The list renderer. Done: `txt_canvas.list`.
2. The tree renderer (recursive indent). Done: `txt_canvas.tree`, over a
   local `tree_lines` depth-first helper. **Test:** a three-level tree
   indents each level by a fixed step; a list's bullets all align in the
   same column. Done.

## Blocked by

- 807a
