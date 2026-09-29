# 807b — Lists and trees

The second piece of 807.

## Current Behavior

No list or tree rendering exists; 807a renders tables only.

## Intended Behavior

Canvas words `list` (bulleted, one level) and `tree` (nested, indented by
depth), both plain text.

## Suggested Implementation Steps

1. The list renderer.
2. The tree renderer (recursive indent). **Test:** a three-level tree
   indents each level by a fixed step; a list's bullets all align in the
   same column.

## Blocked by

- 807a
