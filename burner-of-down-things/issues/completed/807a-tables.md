# 807a — Tables

The first piece of 807: the simplest `.txt` word, and the character-width
discipline every other piece of 807 reuses.

## Current Behavior

Built. `src/072-the-txt-canvas.lua` holds `table(rows)` (space-padded
columns, two spaces between) and `char_width(s)` (a UTF-8 character count,
not a byte count). `list`, `tree`, `box-diagram` and `prose` (807b-d) will
join the same file. Checked by `tests/073-checking-the-txt-canvas.lua`,
which renders a row holding a multi-byte glyph next to a plain row and
checks their second columns start at the same character position.

## Intended Behavior

Canvas word `table`: rows and columns of text, each column padded to its
widest cell, measured in characters — not bytes — so multi-byte glyphs and
box-drawing characters still line up.

## Suggested Implementation Steps

1. Character-width measurement (not byte length).
2. The column-padding renderer. **Test:** every column lines up in
   characters across rows of differing width, including a row holding a
   multi-byte character. Done: `072-the-txt-canvas.lua`'s `table`.

## Blocked by

- 802
