# 029-test-screens — info

Tests for issue 205's checkable parts:
- the exact-shape example (027): every row of widths 1 to 80, five seeds,
  exactly the width, whole known words, fresh per seed;
- the cut reply: mid-word cuts, dropped rows, the message word for word,
  characters not bytes;
- the screen list, the canvases of each mode, and refusals (028);
- the same scripted series of context changes and screens (a phone that
  stops watching) in all three modes: what is painted, in what batches and
  slots, what is held and skipped, and what each screen shows;
- a mode change mid-round, the loading state for a cached size, and the
  mode read from `input/screens`;
- `viewer.layout` (022): letters capped at the maximum and centred, the
  largest size that fits, and the error below the smallest.

    luajit src/029-test-screens.lua [--dir ROOT]
