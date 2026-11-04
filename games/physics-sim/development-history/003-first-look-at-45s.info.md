# 003-first-look-at-45s

## What made it

- taken: 2026-10-21, by a scratch capture script that became
  scripts/picture-the-game; the game run once for 45 seconds and its window
  photographed with ImageMagick's import at 5, 20 and 45 seconds
- commit: f12d85693 (the game as committed in July; binary built in May)
- source fingerprint: 7d626580581a08d2 (the same sources as pictures 004-009)
- input: none intended; see 'What it shows' for evidence of stray input

## What changed since the previous picture

Same run, twenty-five seconds later; no source change.

## What it shows

Forty-five seconds in. The view shows a blue band labelled TOP WRAP ZONE at
the top and an empty dark playfield between the guard rails below it: no pegs,
no gates. The scores kept rising (YOU 6330, THEM 11480, Balls 64, Physics
1.12 ms). The second run (004-009) kept the board in view for a full minute,
so this is almost certainly the view scrolled up past the board by the scroll
wheel reaching the game's window, not the board vanishing.

## The story so far

The game was built in five days in March 2026 (223 commits, 16 to 21
March), declared 167/167 complete on the 19th, repaired on the 21st after a
four-team sprint left its coordinate systems disagreeing, and moved into
games/physics-sim on the 24th. The binary in bin/ was built in May. These
are the first pictures ever taken of it, made on 21 October 2026 while the
project's lodge (issue 114) was being written.
