# The Front Door

Come in. The parlour is closed for the night, but the machines are still lit,
and this one is worth seeing: a pachinko machine written in C, where every
ball falling through the pegs is worked out on a different thread of your
processor at the same moment, and a second machine, upside down beneath the
first, plays against you.

It runs. That is less common in this building than it should be, and it is the
first thing to say about it.

![The game 42 seconds after starting, with nobody at the controls. Blue balls are yours, orange ones the opponent's (the two colours are picked fresh each game, always opposite each other on the colour wheel). The purple streaks are the pieces of balls that broke; the faint ring over the 50 gate is a score ripple. The bottom edge of the opponent's board shows below the gates.](../../development-history/008-second-look-at-42s.png)

## What it is

A board of pegs. You drop balls in at the top; they fall, bounce, and pass
through a row of **gates** worth 10, 50, 100 and 500 points. Below the gates is
a second board, mirrored, belonging to an opponent the machine plays itself.
Its balls fall *upward* through the same gates. When your ball and theirs
meet in the middle, both take damage, and a ball that runs out of health
breaks apart into pieces.

Points buy **upgrades**: balls that spawn faster, balls that are larger, and
**new stages** — whole new boards inserted into the machine, each with its own
row of gates worth more than the last.

There is a second program beside the game: a **board editor**, where boards
are drawn on a grid and saved as files the game loads. You can read about it
in [the workbench](059-the-workbench.md).

## Running it

From the project folder:

```
./run          build the game if needed, then play
./edit         build the board editor if needed, then open it
./config       open the build settings in your editor
```

The first build needs raylib and cJSON fetched and built into `libs/`; the
script that does that is `scripts/build-deps.sh`, and the full steps are in
[the build instructions](../../docs/006-build-instructions.md).

## The controls

| Key | What it does |
|-----|--------------|
| Space | drop a ball (hold to keep dropping) |
| A | turn automatic dropping on or off |
| Left / Right | move where your balls drop |
| Click | switch between steering with the mouse and steering with the keys |
| Tab | open the upgrade menu (Up / Down to choose, hold Enter to buy) |
| Scroll wheel | look up and down the machine |
| P | pause or resume the opponent's dropping |
| H | hide the score and controls panels, for clean pictures |
| F10 | show ball speed statistics |
| R | reset both scores |
| Q, or Esc with no menu open | quit |

One thing worth knowing before you run it unattended: the window takes the
keyboard when it opens, so anything typed while it is in front goes to the
game. That is how automatic dropping got switched on during the first
photographs, and very likely how the view got scrolled away from the board in
one of them.

## The rooms

| Room | What you will find |
|------|--------------------|
| [The machine room](057-the-machine-room.md) | the thread pool underneath everything, and why it needs no locks while the physics runs |
| [The two boards](058-the-two-boards.md) | how a ball is born, scores, collides, wraps and dies; the opponent; the stages |
| [The workbench](059-the-workbench.md) | the board editor, and the board file where colour is physics |
| [The story so far](060-the-story-so-far.md) | how the project was made, day by day, including the day it was declared finished and the day after that |
| [The back shelf](061-the-back-shelf.md) | what is not done, what is stale, and what is still only on paper |

## Elsewhere in the building

- The [vision](../../notes/vision) the project started from, four paragraphs
  and a diagram.
- The [documents](../../docs/000-table-of-contents.md): architecture, the
  thread pool, physics, stages, the editor, the roadmap.
- The [README for the whole ai-stuff repository](../../../../README.md), which
  this project lives inside.
