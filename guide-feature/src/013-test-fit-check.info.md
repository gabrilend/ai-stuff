# 013-test-fit-check — info

Tests for `012-fit-check.lua`:
- a reply that fits, with its rows padded and its counts;
- one reply for each kind of problem, and several at once, in order;
- the report's lines and closing, and the advisory note, compared word for
  word with the blocks and table in `docs/fit-check.md` itself (the document
  wraps lines, so wording is compared, not line breaks);
- the soft budget: far over the recommendation still fits, with the note;
- the blitter's arrival check;
- what it refuses to be called with.

    luajit src/013-test-fit-check.lua [--dir ROOT]
