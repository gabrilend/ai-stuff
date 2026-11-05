# 021-test-marks — info

Tests for `020-marks.lua`, on real blits (104, 106):
- a one-word change marks that word and its sentence, and nothing else;
- a newer change by another voice that ends a sentence early takes over its
  part of the older sentence mark, and the rest keeps the older voice;
- the document's kitten and dog example;
- erased words: one mid-sentence, a sentence's first word (at a row's start
  and just after a full stop), a sentence's last word, and a word whose row
  is left empty;
- expiry with lifetimes of 2 and 0, ages, and a bad lifetime refused;
- orphan marks, and their expiry listed;
- marks through the canvas text and back, and grids and runs;
- the blitter on a throwaway project: marks on each version, expiry across
  versions, the `marks:` log lines, and the receipt's counts.

    luajit src/021-test-marks.lua [--dir ROOT]
