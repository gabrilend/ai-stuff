# 007-test-canvas-text — info

Tests for `005-utf8.lua` and `006-canvas-text.lua`.

The examples in `docs/canvas-format.md` (both header blocks) and
`docs/canvas-protocol.md` (the viewer canvas with its marks) are taken from
the documents themselves. Each is made whole with twenty rows (plain, empty,
exactly sixty characters, sixty two-byte characters, leading spaces), read,
and written back byte for byte. A document edited into a form the reader
refuses fails this test.

Then one malformed canvas for each way a canvas can be wrong, each checked
for its line; what reads but writes back tidier; and what the writer
refuses.

    luajit src/007-test-canvas-text.lua [--dir ROOT]
