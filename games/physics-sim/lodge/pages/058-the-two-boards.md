# The Two Boards

The main floor. Two machines, one above the other, sharing a row of gates
between them. The top one is yours. The bottom one is the opponent's, flipped
upside down so that its balls fall *up*.

![Twenty seconds in, before the board gets busy: the diamond of pegs, the two angled lines either side of the drop point at the top, the gate row with its point values, and below it the top edge of the opponent's board. This game's colours came out cyan for you and red for them.](../../development-history/002-first-look-at-20s.png)

## A ball's life

**Born.** Dropping a ball costs a **credit**. Credits build up over time, 1.7
a second at the start, and each dropped ball spends one, so holding Space
cannot empty a bank that is not there. A ball is not dropped if one of yours
is still sitting too close to the drop point; without that rule, a held key
stacks balls inside each other.

**Falling.** Gravity is 980 pixels per second per second; a ball is 8 pixels
across its radius. Each peg, line and wall it touches sends it off with 70%
of its speed by default (a board can give each object its own bounciness;
see [the workbench](059-the-workbench.md#colour-is-physics)), unless the hit
is gentle. Below 75 pixels a second of closing
speed a ball does not bounce at all; it slides. That rule (issue 220) is what
lets balls settle in a bucket instead of trembling in it forever.

**Scoring.** Passing through a gate scores that gate's points (issue 316 lets
a ball score more than one gate on its way). A ripple spreads from the gate in
the gate's own colour. The gates have small caps on their dividers, bumpers
that soak up speed (issue 605), so a ball cannot simply skate across the top
of the row.

**Meeting the other side.** Your balls and the opponent's can collide. When
they do, both lose health in proportion to how fast they were closing on each
other, but only above 80 pixels a second, so a nudge costs nothing. A ball
starts with 200 health. Above the threshold every pixel a second of closing
speed costs 0.15 health, so a 400-pixel-a-second head-on crash costs 48. Two
of your own balls touching never hurt each other.

**Dying.** At zero health a ball breaks into wedge-shaped pieces that fly off
mostly away from the side that hit it (issue 315), and that tumble and collide
on the way down. In the picture at [the front door](056-the-front-door.md)
the purple streaks are a ball that has just broken.

**Wrapping.** A ball that falls off the bottom of the whole machine comes back
in at the top, keeping its speed and its health, and can score the gates again
on its next way through (issues 708 and 215).

## The opponent

The machine plays the bottom board itself. Its drop point slides back and
forth along a track and drops a ball whenever it has a credit, at 1.3 a
second, a little slower than you start. P pauses it.

Its board is yours turned upside down. The flip formula was wrong at first:
it turned row 0 into row 22 on a 22-row grid, one past the edge, which put
objects in the wrong places on the opponent's side. The fix (issue 1001c) is
the classic one, *rows minus one minus row*.

The two scores are kept apart (issue 609): the panel shows YOU, THEM and the
best you have reached.

## Upgrades and stages

Tab opens the upgrade menu. Three things are for sale:

- **Spawn rate**, in many small steps; holding Enter keeps buying (issue 511).
- **Ball size**, a bigger ball that hits more pegs and gets in the way more.
- **Next stage**: a whole new board inserted into the machine, with its own
  gate row worth more than the one above it.

Buying a stage pauses the physics, slides the existing machine apart, inserts
the new board, and zooms the view out to show it (issues 701 to 707). The new
board is picked at random from the files in the `boards/` folder, each used
once before any repeats (issue 811), which is how boards drawn at
[the workbench](059-the-workbench.md) end up in the game. The opponent gets
the same board, flipped. Only when no board file can be loaded does the game
fall back to a built-in stage of two ramps funnelling balls into the middle,
and it prints a warning when it does.

## Where to read more

- [The physics document](../../docs/003-physics-system.md), and the
  [stage system](../../docs/009-stage-system.md).
- [The balance log](../../docs/balance-updates.md), which records every
  number above that was changed, with the reason. Two entries from it: the
  drop rate was cut from 5 a second to 1.7 because "initial spawn rates were
  too fast, making the game feel rushed from the start"; and balls got a
  damage threshold because "even slow 50 px/sec collisions dealt 5 damage,
  causing balls to die from insignificant contact."
