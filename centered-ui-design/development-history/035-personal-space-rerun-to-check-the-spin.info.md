<!-- made by scripts/file-screenshot on 2026-10-10 22:15, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 035 — personal-space-rerun-to-check-the-spin

- **Picture:** 035-personal-space-rerun-to-check-the-spin.png
- **Commit:** 8341309b1 2026-10-10 centered-ui-design: the console spins by hand, every arch drawn whole
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/017-the-tests.test.lua
  -  M src/020-ceramic-boxes.c

## What changed

Compared with picture 034:
- no source or settings file changed (same program, different run or moment)


## What it shows

A rerun to tell the stray spin from a bug: most of the picture is black,
only the bottom-right corner drawn (the console's right end and a little of
the world) — the window was resized or covered while the game ran. Kept as
a record of the run.

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
