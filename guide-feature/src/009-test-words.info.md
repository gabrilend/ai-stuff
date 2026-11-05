# 009-test-words — info

Tests for `008-words.lua`:
- words at a row's first and last column, a word filling the row, runs of
  spaces, characters of two and three bytes, punctuation inside a word, and
  no wrapping;
- the cell grid, in characters, and its refusal of a word off the canvas;
- sentences across rows, ended by an empty row or a row of spaces, by `.`
  `!` `?`, and past closing quotes and brackets;
- one whole canvas read by 006.

    luajit src/009-test-words.lua [--dir ROOT]
