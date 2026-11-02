# 155-the-motion.lua

The `.mp4` end's motion (docs/067, issue 806 step 1): the `.mp4`
paintbrush (the `.png` words plus `frames`, `rate`, `move`) read through
the wall, and each frame worked out from its number alone. Painting frames
is the `.png` painter's (803); encoding is step 3's.

A **move**: a named surface's `colour` (from and to colours) or `offset`
(from and to points, added to every corner), from frame `start` (default
0) to `stop` (default the last). Frame n is `from` plus `fraction` of the
way to `to`: 0 at and before `start`, 1 at and after `stop`, linear
between; colours round to whole channels.

| Function | In | Out |
|---|---|---|
| `read(text, where)` | a `.mp4` canvas's text | `{still, count, rate, moves}` (`still` is 151's compiled canvas), or nil and every finding: the wall's, a move naming no surface (with the nearest), a value that does not fit its field, frames out of range |
| `frame(clip, n)` | `read`'s clip; 0 .. count-1 | frame n's compiled canvas, a new table; the still is never changed. Arrows whose end is a moving surface move with it |
| `fraction(move, n)` | a move; a frame | how far through it frame n is, 0 to 1 |
| `MP4`, `FIELDS` | | the `.mp4` paintbrush (its document: `docs/paintbrush-mp4.md`); `colour`, `offset` |
