# 011-test-changes — info

Tests for `010-changes.lua`. Each case checks all four lists and both counts:
- the issue's cases: no change, one word replaced, a word moved one column,
  a word erased, a whole sentence rewritten, and a word overwritten by a
  longer one (the `kitten` example);
- an operative word changed (`very` to `not very`), a sentence erased or
  partly kept, words written into empty space, changed punctuation, rows
  without trailing spaces, a word moving rows, characters of two bytes;
- the word numbers carried, canvas records read by 102, and different
  heights refused.

    luajit src/011-test-changes.lua [--dir ROOT]
