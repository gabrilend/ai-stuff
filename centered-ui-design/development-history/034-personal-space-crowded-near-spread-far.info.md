<!-- made by scripts/file-screenshot on 2026-10-10 22:14, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 034 — personal-space-crowded-near-spread-far

- **Picture:** 034-personal-space-crowded-near-spread-far.png
- **Commit:** 863b18019 2026-10-10 centered-ui-design: the console spins by hand, every arch drawn whole
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/017-the-tests.test.lua
  -  M src/020-ceramic-boxes.c

## What changed

Compared with picture 033:
- commit: e845da886 -> 863b18019
- changed: src/017-the-tests.test.lua
- changed: src/020-ceramic-boxes.c


## What it shows

The arch view at noon with personal space on. The console has been spun
part way toward seat 4 — not by the script: a real mouse on the window
(the stuck-hold fault, fixed in 039) — so seat 4's arch is in front with SEAT 4
in its slot and seat 4's lime section to the right of center, seat 1's
brown quadrant at the left. The frame counter reads 115.

## The story so far

After the console learned to spin by hand (032-033), the owner asked for
villagers near the console to crowd closer while drawn full size — "the
pathing radius shrinks the closer they are to you" — so each ring holds
about as many as any other; the engine now gives each a personal space
that grows with its ring (034-035). Then two view dials, turned by the
wheel with a key held: A for view distance (how far the top of the screen
reaches, which sets how fast distant units seem to move) and S for field of
view (the arch's span, squeezing more in from the sides) (036-041). On the
way, the window opening on the owner's own screen exposed a fault: a press
on the console let go outside the window left it held, so later mouse moves
spun it (034, 037); it now lets go when a move arrives without the button.
Partial pictures (035, 036) are the window being resized or covered while
running; kept, like every picture.
