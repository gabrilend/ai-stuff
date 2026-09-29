# 072-the-txt-canvas.lua

The `.txt` end's canvas words (docs/067). So far only `table` (issue 807a);
`list`, `tree`, `box-diagram` and `prose` (807b-d) are later pieces that will
join this file.

| Function | In | Out |
|---|---|---|
| `table(rows)` | array of arrays of strings, one array per row | the rows rendered as space-padded columns (two spaces between), one line per row, widths measured in characters |
| `char_width(s)` | a UTF-8 string | its length in characters, not bytes |
