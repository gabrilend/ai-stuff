# 015-test-blit — info

Tests for `014-blit.lua`, each checking the canvas that results and the
report:
- the example in `docs/datapath-blit.md`, read from the document itself:
  `kitten` over `the cat sat on the mat`, then `dog` over `kitten`, under
  `blank-whole` and `keep-fragments`;
- the issue's cases: a write exactly covering a word, one spanning three
  words, a removal of a word another voice already changed (and one still
  there), and two writes in one blit that touch;
- another voice's later words left alone, a word touching the write, two-byte
  characters, a write changing nothing, several rows, the current canvas left
  unchanged, and the refusals.

    luajit src/015-test-blit.lua [--dir ROOT]
