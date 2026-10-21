# The Workbench

In the back, under a work lamp: the bench where boards are made. It is a
separate program, `bin/board-editor`, built and opened with `./edit`. The
game never draws a board itself any more; it reads one from a file this
bench wrote.

![The editor as it opens: a blank 14 by 22 grid of 43-pixel cells, the six tools along the top, a tools drawer on the left, properties and board statistics on the right, and "(unsaved)" in the status line. Two small faults are visible in this picture: the "1:Peg" button sits over the end of the "BOARD EDITOR" title, and the drawer on the left lists five tools where the top bar has six (Track is missing from the drawer).](../../development-history/010-editor-first-look-at-4s.png)

## The tools

| Key | Tool | What it places |
|-----|------|----------------|
| 1 | Peg | a round peg on a grid crossing |
| 2 | Line | a thick line with rounded ends, from one crossing to another |
| 3 | Portal in | a zone that swallows balls |
| 4 | Portal out | a zone where they come back out; ins and outs pair by channel number |
| 5 | Rotor | a hub; lines touching it spin around it |
| 6 | Track | a path that a mover, and whatever is attached to it, travels along |

Tab switches between placing and selecting. S saves, L loads, N starts a new
board. In the file picker, j and k move and the arrow keys work too
(issue 831). Dragging a box selects many objects at once so they can be
edited together (issue 834).

Everything snaps to the **crossings** of the grid, not the middles of the
cells, so two lines that meet at a crossing really meet. When lines close a
shape, the editor finds the closed loop and fills it, and the game treats
the filled shape as solid (issue 837).

## Colour is physics

Every object carries a colour, and the colour *is* its physics:

| Channel | What it controls | 0 means | 255 means |
|---------|------------------|---------|-----------|
| Red | bounciness | a dead stop | more bounce than it came in with |
| Green | grip | ice | sticky |
| Blue | bonus points | nothing | points every time a ball touches it |

So a reddish peg is lively, a green-heavy line holds a rolling ball, and a
blue peg pays. You can read a board's behaviour off its colours before a
single ball is dropped.

Editing raw numbers is not friendly, so the editor offers **materials**
instead (issue 839): Stone, Ice, Rubber, Sticky, Bouncy, Glass and Metal,
each a preset colour, with Custom for anything else. Setting
`EDITOR_ADVANCED_MODE=1` in `config` swaps the materials for three sliders
that move in steps of a tenth (issue 833).

## The board file

A board is a small JSON file in `boards/`: a name, the grid's size, and a
list of objects by grid position. The default board, *Stage 1 - Classic
Pegs*, is 97 pegs, 4 lines and 14 scoring gates on a 14 by 22 grid. Its
first lines:

```
{
  "version": 1,
  "name": "Stage 1 - Classic Pegs",
  "grid": { "columns": 14, "rows": 22 },
  "objects": [
    {"type": "peg", "col": 6, "row": 2},
    {"type": "peg", "col": 8, "row": 2},
```

Every board in `boards/` is a candidate stage: when a player buys a new
stage in the game, one is picked at random (see
[the two boards](058-the-two-boards.md#upgrades-and-stages)). Drawing a board
here is adding a level to the game.

## How the bench came to stand on its own

The editor began *inside* the game, on the 17th of March: a mode you toggled
into, placing objects over the running board, saving through a file dialog.
That night it became an overlay drawn on top of play. Early on the 18th it
was taken out entirely and made its own program, in one commit that closed a
phase (issues 815 and 816). From then on there are two programs that share a
file format, not one program with two modes. The story of that day is in
[the story so far](060-the-story-so-far.md#18-march-two-programs).

One lesson from that split: the editor and the game disagreed about the
size of a board, and the fix found that the *editor* had been right all
along, so the game was changed to match it rather than meeting in the
middle (issue 819). The rule that came out of it is written in that issue:
"Boards should be 'hot-swappable' - like playing cards being moved around on
a table." Later, when the grid became 14 by 22, the board files
stopped storing their own pixel dimensions at all, because a second copy of
a number is a number that can disagree (issue 838).

The full description is in [the board editor document](../../docs/010-board-editor.md).
