# 001-first-look-at-5s

## What made it

- taken: 2026-10-21, by a scratch capture script that became
  scripts/picture-the-game; the game run once for 45 seconds and its window
  photographed with ImageMagick's import at 5, 20 and 45 seconds
- commit: f12d85693 (the game as committed in July; binary built in May)
- source fingerprint: 7d626580581a08d2 (the same sources as pictures 004-009)
- input: none intended; see 'What it shows' for evidence of stray input

## What changed since the previous picture

Nothing: the first picture.

## What it shows

Five seconds in. Score panel YOU 0, THEM 0, Balls 7, FPS 60, Physics 0.23 ms,
Threads 11. The top of the player's board: the two angled lines either side of
the drop point, the first rows of the peg diamond, the drop reticle (a blue
ring) at the top centre. A large black rectangle covers most of the middle of
the picture: another window lay over the game when it was captured, and
import photographs the screen, not the game's own buffer. The gate row
(10 50 100 500 100 50 10) and the top of the opponent's board show below it.

## The story so far

The game was built in five days in March 2026 (223 commits, 16 to 21
March), declared 167/167 complete on the 19th, repaired on the 21st after a
four-team sprint left its coordinate systems disagreeing, and moved into
games/physics-sim on the 24th. The binary in bin/ was built in May. These
are the first pictures ever taken of it, made on 21 October 2026 while the
project's lodge (issue 114) was being written.
