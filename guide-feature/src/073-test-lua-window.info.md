# 073-test-lua-window — info

Tests the Lua window (issue 802), all but the window itself.

    luajit src/073-test-lua-window.lua --dir ROOT

- **Settings**: `input/lua-window` reads; a colour not `#rrggbb`, a
  strength above 1, an empty list, a scale below 1 and a write time of 0
  are refused, naming the file.
- **Colours**: the background for no mark; a voice's colour over it at the
  strength for the mark's kind and age (a literal check, rounded); word
  stronger than sentence; fading with age; the last strength past the
  list; orphan as sentence; kuvalu's colour; a fifth voice round again; an
  unlisted voice none.
- **Letters**: every printable character has a picture; the ones drawn here
  are 8x8 and only for what the font lacks; a letter beyond ASCII is the
  hollow box; a space is blank.
- **Writing over**: "sat" to "ran" is one run though its "a" stayed; each
  word its own run, all ending together; the first version over a blank;
  the old character and old colour until a cell turns; a third of the way;
  all written at the end; the text grid's signs (on `04-aging` too).
- **Picture and PNG**: its size; the test's own PNG reader (CRCs, stored
  blocks, no filters, Adler-32); background, ink and mark colours pixel by
  pixel, every pixel of one letter; scale 1.
- **The program** (pretend clock): a replay with one unreadable file and two
  screenshots, the receipt, frames only while writing, the screenshot at
  0.2 s into a version half written ("dat"), numbering after waiting
  screenshots; a version cut short and what the next is written over;
  `q`, `space` twice, `s`, an unknown key; the live canvas; then
  `scripts/lua-window` on the real clock with a new version, the stop file,
  and its screenshot filed into `development-history/` after what is there,
  with its note; refused arguments and settings; a real-clock replay.
