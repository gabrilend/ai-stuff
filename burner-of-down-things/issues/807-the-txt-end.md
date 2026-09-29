# 807 — The .txt end

Text assets: `table`, `list`, `tree`, `box-diagram` (boxes of line characters, arrows there — here), `prose` (a template with slots) ([067](../docs/067-datapath-the-studio.md)).

## Current Behavior

Nothing writes text assets.

## Intended Behavior

The same wall and compilation as the other ends; widths measured in characters, not bytes, so box-drawing characters line up. Output is the file exactly as written, and its card.

## Suggested Implementation Steps

1. Tables and lists. **Test:** every column lines up in characters.
2. Box diagrams with arrows. **Test:** a two-box diagram with one arrow matches a stored expected file byte for byte.
3. Prose templates. **Test:** a missing slot is a finding, never a blank.

## Blocked by

- 802
