# 002-first-look-at-20s

## What made it

- taken: 2026-10-21, by a scratch capture script that became
  scripts/picture-the-game; the game run once for 45 seconds and its window
  photographed with ImageMagick's import at 5, 20 and 45 seconds
- commit: f12d85693 (the game as committed in July; binary built in May)
- source fingerprint: 7d626580581a08d2 (the same sources as pictures 004-009)
- input: none intended; see 'What it shows' for evidence of stray input

## What changed since the previous picture

Same run, fifteen seconds later; no source change.

## What it shows

Twenty seconds in, unobstructed. The whole peg diamond (a staggered grid
narrowing to a point at the bottom), cyan player balls and red opponent balls
falling through it, a faint grey ring at the lower left (a score ripple), the
gate row, and the top rows of the opponent's mirrored board below. The panel
reads YOU 10, THEM 2590, Balls 49, Physics 0.53 ms, and the controls panel now
shows [AUTO-SPAWN] in green: automatic dropping was switched on between 5 and
20 seconds, which only the A key does, so a keypress reached the game's
window. Used in the lodge's 'two boards' room.

## The story so far

The game was built in five days in March 2026 (223 commits, 16 to 21
March), declared 167/167 complete on the 19th, repaired on the 21st after a
four-team sprint left its coordinate systems disagreeing, and moved into
games/physics-sim on the 24th. The binary in bin/ was built in May. These
are the first pictures ever taken of it, made on 21 October 2026 while the
project's lodge (issue 114) was being written.
