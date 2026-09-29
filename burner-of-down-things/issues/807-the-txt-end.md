# 807 — The .txt end

Text assets: `table`, `list`, `tree`, `box-diagram` (boxes of line characters, arrows there — here), `prose` (a template with slots) ([067](../docs/067-datapath-the-studio.md)).

## Current Behavior

807a is built (issues/completed/807a-tables.md): the `table` word, with the
character-width discipline the rest of this end reuses. 807b (lists and
trees), 807c (box diagrams) and 807d (prose templates) are not yet built.

## Intended Behavior

The same wall and compilation as the other ends; widths measured in characters, not bytes, so box-drawing characters line up. Output is the file exactly as written, and its card.

## Suggested Implementation Steps

1. Tables and lists. **Test:** every column lines up in characters.
2. Box diagrams with arrows. **Test:** a two-box diagram with one arrow matches a stored expected file byte for byte.
3. Prose templates. **Test:** a missing slot is a finding, never a blank.

## Sub-issues

- 807a — tables
- 807b — lists and trees
- 807c — box diagrams
- 807d — prose templates

## Blocked by

- 802
